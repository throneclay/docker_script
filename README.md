# docker scripts

docker development helper scripts

this is a project docker scripts collection.

easy to use..

## quick start

inside your project, you can add submodule as follow 
```
git submodule add https://github.com/throneclay/docker_script docker
```

to create the custom.sh and env_setup.sh, run these
```
# check script, if you don't have one, it will create for you.
# default path is scripts/
# the first launch is to create custom.sh
# the second launch is to create env_setup.sh

bash docker/dstart.sh
bash docker/dstart.sh
```

once you have your own custom.sh, you can start docker env

```
bash docker/dstart.sh create
```

if you want to get inside docker
```
bash docker/dinto.sh
```