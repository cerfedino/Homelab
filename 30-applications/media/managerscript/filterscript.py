#!/usr/bin/env python3
import os
import sys
import time
import traceback

import qbittorrentapi
from discord_webhook import DiscordWebhook
from paramiko import SSHClient

QB_HOST = os.environ["QB_HOST"]
QB_PORT = int(os.environ.get("QB_PORT", "443"))
QB_USER = os.environ["QB_USER"]
QB_PASS = os.environ["QB_PASS"]

SSH_HOST = os.environ["SSH_HOST"]
SSH_USER = os.environ["SSH_USER"]
SSH_PASSWORD = os.environ["SSH_PASSWORD"]
SSH_PORT = int(os.environ.get("SSH_PORT", "22"))
KNOWN_HOSTS = os.environ.get("KNOWN_HOSTS", "/app/known_hosts")

DISCORD_WEBHOOK_URL = os.environ.get("DISCORD_WEBHOOK_URL", "")

# stdout is the log in kubernetes
ACTIVITY_LOG = os.environ.get("ACTIVITY_LOG", "/dev/stdout")


def log_activity(action, torrent_name, size_bytes):
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    size_gb = round(size_bytes / (10**9), 2)
    with open(ACTIVITY_LOG, "a") as f:
        f.write(f"{ts} {action} [{size_gb} GB] {torrent_name}\n")


class OutputBuffer:
    """Buffers log lines and optionally flushes them to stdout + Discord."""

    def __init__(self, webhook_url=None):
        self._lines = []  # list of (message, send_to_discord)
        self.webhook_url = webhook_url

    def log(self, msg, discord=True):
        """Append a message to the buffer. If discord=False, it will only go to stdout on commit."""
        for line in msg.split("\n"):
            self._lines.append((line, discord))

    def commit(self):
        """Print all buffered lines to stdout and send discord-eligible lines to the webhook."""
        ts = time.strftime("%Y-%m-%d %H:%M:%S")
        for line, _ in self._lines:
            print(f"{ts} INFO     {line}")
        sys.stdout.flush()

        if self.webhook_url:
            discord_text = "\n".join(
                line for line, to_discord in self._lines if to_discord
            )
            if discord_text.strip():
                self._send_webhook(discord_text)

        self._lines.clear()

    def discard(self):
        """Drop all buffered lines without printing or sending anything."""
        self._lines.clear()

    def _send_webhook(self, body):
        """Send body to Discord, splitting into <=2000-char chunks."""
        body = body.replace("\t", "    ")
        chunk = ""
        for line in body.split("\n"):
            # If adding this line would exceed the limit, send what we have first
            if chunk and len(chunk) + len(line) + 1 > 2000:
                DiscordWebhook(
                    url=self.webhook_url, content=chunk.rstrip("\n")
                ).execute()
                chunk = ""
            chunk += line + "\n"
        # Send the remaining chunk
        if chunk.strip():
            DiscordWebhook(url=self.webhook_url, content=chunk.rstrip("\n")).execute()


class color:
    PURPLE = "\033[95m"
    CYAN = "\033[96m"
    DARKCYAN = "\033[36m"
    BLUE = "\033[94m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    BOLD = "\033[1m"
    UNDERLINE = "\033[4m"
    END = "\033[0m"


def has_met_seeding_goals(t):
    """Check if a torrent has finished downloading and met at least one of its configured seeding limits (ratio, seeding time, inactive seeding time). Returns False for torrents with no limits set — they are never auto-deletable."""
    # Must have finished downloading
    if t["amount_left"] > 0:
        return False

    # Ratio limit met?
    if t.get("max_ratio", -1) >= 0 and t["ratio"] >= t["max_ratio"]:
        return True

    # Seeding time limit met? (max is in minutes, seeding_time is in seconds)
    if (
        t.get("max_seeding_time", -1) >= 0
        and t["seeding_time"] >= t["max_seeding_time"] * 60
    ):
        return True

    # Inactive seeding time limit met? (max is in minutes)
    max_inactive = t.get("max_inactive_seeding_time", -1)
    if max_inactive >= 0 and t.get("last_activity", 0) > 0:
        inactive_seconds = time.time() - t["last_activity"]
        if inactive_seconds >= max_inactive * 60:
            return True

    return False


def get_completed_torrents(qb: qbittorrentapi.Client):
    """Return torrents that have met their seeding goals and are candidates for deletion."""
    return [
        t
        for t in qb.torrents_info()
        if has_met_seeding_goals(t) and "keep" not in t["tags"]
    ]


def get_torrents_in_queue(qb: qbittorrentapi.Client):
    """Return torrents that are waiting to start. A torrent is considered enqueued if it has the "dumped" tag"""
    return [t for t in qb.torrents_info() if "dumped" in t["tags"]]


def get_torrents_downloading(qb: qbittorrentapi.Client):
    """Returns torrents that are currently in download state"""
    return [t for t in qb.torrents_info() if t["state"] in ["downloading"]]


LIMIT_ACTIVE_DOWNLOADS = {
    "hd-space.pw": sys.maxsize,
    "itatorrents.xyz": 1,
}


def start_torrent(qb: qbittorrentapi.Client, torrent_hash: str):
    qb.torrents_start(torrent_hashes=torrent_hash)
    # if t.trackers[0] in LIMIT_ACTIVE_DOWNLOADS:
    #     LIMIT_ACTIVE_DOWNLOADS[t.trackers[0]] -= 1


def delete_torrent(qb: qbittorrentapi.Client, torrent_hash: str):
    qb.torrents_delete(permanently=True, delete_files=True, torrent_hashes=torrent_hash)


def remove_tags(qb: qbittorrentapi.Client, torrent_hash: str, tags: str):
    qb.torrent_tags.remove_tags(torrent_hashes=torrent_hash, tags=tags)


def get_used_space_ssh(qb: qbittorrentapi.Client):
    """Get used disk space in bytes"""
    client = SSHClient()
    try:
        client.load_system_host_keys(KNOWN_HOSTS)
        client.connect(
            hostname=SSH_HOST, port=SSH_PORT, username=SSH_USER, password=SSH_PASSWORD
        )  # key_filename=SSH_KEY, passphrase=SSH_PASSPHRASE)

        _, stdout, _ = client.exec_command(
            """quota -w 2>/dev/null | awk '/\\/dev\\//{print ($2) * 1024, ($4) * 1024}'"""
        )
        output = stdout.read().decode().strip().split(" ")
        used = int(output[0])
        quota = int(output[1])
    finally:
        client.close()

    return used, quota


def get_quota_ssh(client):
    """Get disk quota in bytes"""
    return 4 * (10**12) + 10 * (10**9)  # 4 TB


def get_space_info(qb: qbittorrentapi.Client):
    used_space, quota_space = get_used_space_ssh(qb)
    return (used_space, quota_space)


def main():
    buf = OutputBuffer(webhook_url=DISCORD_WEBHOOK_URL)

    qb = qbittorrentapi.Client(
        host=QB_HOST,
        port=QB_PORT,
        username=QB_USER,
        password=QB_PASS,
        FORCE_SCHEME_FROM_HOST=True,
    )
    try:
        qb.auth_log_in()
        ts = time.strftime("%Y-%m-%d %H:%M:%S")
        print(f"{ts} INFO     Successfully connected to qBittorrent API")
    except Exception as e:
        print(e)
        sys.exit(1)

    while True:
        torrents_started = False
        try:
            used_space, quota_space = get_space_info(qb)
            used_space += 50 * (10**9)  # add 50GB of buffer

            completed_torrents = get_completed_torrents(qb)
            completed_torrents.sort(key=lambda x: x["popularity"])

            queued_torrents = get_torrents_in_queue(qb)
            queued_torrents.sort(key=lambda x: x["added_on"], reverse=True)
            downloading_torrents = get_torrents_downloading(qb)

            buf.log("## Completed torrents:", discord=False)
            buf.log(
                "\n".join(
                    [
                        f"\t[{round(t['size'] / (10**9), 2)} GB] {t['name']}"
                        for t in completed_torrents
                    ]
                    or ["-"]
                ),
                discord=False,
            )
            buf.log("\n## Torrents in queue:", discord=False)
            buf.log(
                "\n".join(
                    [
                        f"\t[{round(t['size'] / (10**9), 2)} GB] {t['name']}"
                        for t in queued_torrents
                    ]
                    or ["-"]
                ),
                discord=False,
            )
            buf.log("\n## Torrents downloading:", discord=False)
            buf.log(
                "\n".join(
                    [
                        f"\t[{round(t['size'] / (10**9), 2)} GB] {t['name']}"
                        for t in downloading_torrents
                    ]
                    or ["-"]
                ),
                discord=False,
            )

            BUFFER = 50 * (10**9)
            actual_used = used_space - BUFFER
            buf.log(
                f"\nUsed: {round(actual_used / (10**9), 2)} GB, Quota: {quota_space / (10**9)} GB, Free: {round((quota_space - actual_used) / (10**9), 2)} GB (50 GB buffer reserved)\n",
                discord=False,
            )

            if len(queued_torrents) != 0:
                buf.log("## Starting torrents in queue")
            # Iterate through every torrent we want to start
            for t in queued_torrents:
                buf.log(
                    f"- **Evaluating torrent: [{round(t['size'] / (10**9), 2)} GB] {t['name']}**:"
                )
                # if t.trackers[0] in LIMIT_ACTIVE_DOWNLOADS and LIMIT_ACTIVE_DOWNLOADS[t.trackers[0]] < 1:
                #     buf.log(f"\t[-] Tracker {t.trackers.split(',')[0]} has limit of {LIMIT_ACTIVE_DOWNLOADS[t.trackers.split(',')[0]]} active downloads. Skipping torrent.")
                #     continue

                if used_space + t["size"] >= quota_space:
                    # If we don't have enough space for the new torrent, we try to remove just enough completed torrents to make enough room
                    to_free = (used_space + t["size"]) - quota_space
                    buf.log(
                        f"\t[-] Not enough space. Missing {round(to_free / (10**9), 2)} GB. Freeing up space by deleting torrents"
                    )

                    # Gather list of completed torrents to delete such that we have just enough space
                    torrents_to_delete_hashes = []
                    freed = 0
                    for ct in completed_torrents:
                        if freed >= to_free:
                            break
                        freed += ct["size"]
                        torrents_to_delete_hashes.append(ct["hash"])

                    # If we would get enough space
                    if freed >= to_free:
                        buf.log(
                            f"\t[+] Freed {round(freed / (10**9), 2)} GB by deleting {len(torrents_to_delete_hashes)} torrents."
                        )

                        # Delete all gathered torrents
                        for hash in torrents_to_delete_hashes:
                            torrent = qb.torrents_info(torrent_hashes=hash)[0]
                            buf.log(
                                f"\t\tDeleted torrent: [{round(torrent['size'] / (10**9), 2)} GB] {torrent['name']}"
                            )
                            log_activity("REMOVED", torrent["name"], torrent["size"])
                            completed_torrents = [
                                ct for ct in completed_torrents if ct["hash"] != hash
                            ]
                        used_space = used_space - freed

                        delete_torrent(qb, torrents_to_delete_hashes)
                    else:
                        buf.log(f"\tCould not free enough space. Skipping torrent.")
                        continue

                used_space += t["size"]
                buf.log(
                    f"\t[+] Starting torrent. Used space now: {(used_space - BUFFER) / (10**9)} GB"
                )

                start_torrent(qb, t["hash"])
                remove_tags(qb, t["hash"], "dumped")
                log_activity("STARTED", t["name"], t["size"])
                torrents_started = True

            actual_used = used_space - BUFFER
            buf.log(
                f"\nUsed now: {round(actual_used / (10**9), 2)} GB, Quota: {quota_space / (10**9)} GB, Free now: {round((quota_space - actual_used) / (10**9), 2)} GB (50 GB buffer reserved)\n"
            )

        except Exception as e:
            buf.log(f"ERROR: {traceback.format_exc()}")
            buf.commit()
        else:
            if torrents_started:
                buf.commit()
            else:
                buf.discard()

        time.sleep(60 * 4)


if __name__ == "__main__":
    main()
