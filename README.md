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

## Docker DB Backup
This script automates backups of databases running inside Docker containers (MySQL, MariaDB, PostgreSQL). It supports daily and monthly backups, retention cleanup, and optional cron setup.

### Setup Cron
This creates /etc/cron.d/docker-db-dumps with:
- Daily backup at 08:00
- Monthly backup on the 1st at 08:30
```
sudo ./docker-db-backup/docker-db-backup.sh --setup
```

### Structure
Backups are stored in:
```
/var/backups/docker-db-dumps/
  ├── daily/
  │   └── YYYY-MM-DD/
  │       └── <engine>/<project>/<db>.sql.bz2
  └── monthly/
      └── YYYY-MM-DD/
          └── <engine>/<project>/<db>.sql.bz2
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
