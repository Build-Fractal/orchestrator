# Suppression fixture: forbidden region must not flag

```bash
# FORBIDDEN: the following lines demonstrate a forbidden pattern
bash foo.sh --at=$(date)
result=`echo x`
bash {a,b}.sh
```
