# Automated test for cellsim_34_vcl

Scripts to run a test of the cellsim_34_vcl code as a cron job, e.g. by adding
something like this to your crontab:

```
0 23 * * 4 /path/to/cellsim_pan_test/cellsim_test.sh > /dev/null 2>&1
```

and copying the config file to your home directory, e.g.

```
cp /path/to/cellsim_pan_test/cellsim_test.conf ~/.cellsim_test.conf
```

and editing it as required.
