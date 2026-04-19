# Saiba Tenpura's Scripts
My personal scripts I use on a regular basis.

## Sparse Checkout
If you only need or want specific scripts you can sparse checkout the scripts you need.

For example if you only need the backup scripts:
```
git init
git remote add origin git@github.com:saiba-tenpura/scripts.git
git sparse-checkout init
git sparse-checkout set "backup" "docker-db-backup"
git checkout main
```

## License
[MIT](./LICENSE)
