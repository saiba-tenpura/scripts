# Saiba Tenpura's Scripts
My personal scripts I use on a regular basis.

## Restic Backup Script
A lightweight wrapper script around Restic for automated backups, retention management, and optional syncing to external drives.

### Setup Repo & Cron
```
cp config-example.sh config.sh
# Adjust the config to match your needs
sudo ./restic-backup/backup.sh --setup
Password:
Confirm Password:
Init new restic repository!
created restic repository at /var/backups/restic-repo
Setup crontab!
```

## Sparse Checkout
If you only need or want specific scripts you can sparse checkout the scripts you need.

For example if you only need the backup scripts:
```
git init
git remote add origin git@github.com:saiba-tenpura/scripts.git
git sparse-checkout init
git sparse-checkout set "restic-backup" "docker-db-backup"
git checkout main
```

## License
[MIT](./LICENSE)
