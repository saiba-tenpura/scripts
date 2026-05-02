# Saiba Tenpura's Scripts
My personal scripts I use on a regular basis.

## Restic Backup
A lightweight wrapper script around Restic for automated backups, retention management, and optional syncing to external drives.

### Setup Repo & Cron
```
cp config-example.sh config.sh
# Adjust the config to match your needs
sudo ./restic-backup/restic-backup.sh --setup
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


## TrueNAS ACME
A shell script for issuing automated DNS challenges via the TrueNAS ACME authenticator by using the acme.sh project.

### Setup Script
Clone the acme.sh repository into the script directory or configure **ACME_DIR** in your config.sh to wherever you cloned it to.
```
git clone https://github.com/acmesh-official/acme.sh.git truenas-acme/acme.sh
```

Copy the config file, configure one of the [many providers](https://github.com/acmesh-official/acme.sh/wiki/dnsapi2) and it's necessary credentials.
```
cp truenas-acme/config-example.sh truenas-acme/config.sh
```

Login to your TrueNAS instance and under Credentials > Certificates:
- Add an ACME DNS-Authenticators:
  - **Authenticator:** /path/to/truenas-acme.sh
  - **User:** Any user which is able to run the script
  - **Timeout:** 300
  - **Delay:** 120
- Add a Certificates Signing Request
- For the newly created CSR > Create ACME Certificate
  - Check if it works with Let's Encrypt Staging first
  - If everything worked create a new one with the Production Directory
- Under System > General Settings > GUI > Settings > GUI SSL Certificate select the ACME certificate

### Logging
Logs are by default written to **truenas-acme.log** relative to the script dir.


## Git Mirror
A shell script for mirroring all repositories of a GitHub account to a Gitea instance. (Requires: jq)

### Setup
Copy the config file, configure the [GitHub](https://github.com/settings/personal-access-tokens) as well as the [Gitea](https://gitea.example.com/user/settings/applications) token and exclude repositories which you don't want to be synced.
```
cp git-mirror/config-example.sh git-mirror/config.sh
```

### Execution
If everything has been configured correctly you should be able to just run the script and then see every repository being cloned from GitHub and then being pushed to Gitea.
```
./git-mirror/git-mirror.sh
```


## Miscellaneous

### Install Latest GE
Installs the latest release of the proton-ge-custom compatibility layer by GloriousEggroll to the corresponding steam folder.
```
./misc/install-latest-ge.sh
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
