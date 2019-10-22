# polly - a gitops native, single tenant, micro ci laboratory

polly can be used to debug several types of ci platforms

# .circleci/config.yml

polly understands circleci config and is able to plan and execute workflows on a local or remote kubernetes cluster

# installation

    cd ~/workspace
    git clone git@github.com:unhookd/polly.git
    cd polly
    make install #NOTE: will prompt for sudo password

# initial polly deploy to local kubeadm cluster

    cd ~/workspace/myproj
    polly build # build polly controller Dockerfile
    polly init # install polly controller into desired kubernetes context

# polly push

the `push` command will push the git repo from `$PWD` to the polly controller

_requires_ `$PATH/git` to be present.

begins pipeline by sending latest commits to git remote controller

git remote controller will process inbound commits via `git-receive-pack`

current local branch will be stored into bare repo

event hooks are dispatched

    cd ~/workspace/myproj
    git status # polly requires a valid git repo to work

    polly push # install current PWD as a project in the deployed polly controller

# polly test

the `test` command will run the auto-detected workflow (currently supports detection of .circleci/config.yml)

    polly test --dry-run # emit plan for execution for detected ci workflow

    polly test # execute detected ci workflows

# polly dev

the `dev` command is a tool to help local development by executing `Procfile`

    cd ~/workspace/myproj
    cat Procfile # ensure you have a Procfile present, see below for example

      # example Procfile
      one: sleep 5 && echo true
      two: sleep 2 && echo false

    polly dev # will run commands in Procfile

# polly changelog

the `changelog` command is a tool that appends to development journal CHANGELOG.md by default.

Useful for creating notes, or making blank commits for pushing into a git+ops pipeline

# polly build

_requires_ `$PATH/docker` and access to a working `/var/lib/docker.sock`

build `$APP:latest` using the `Dockerfile` from the HEAD version of the current working directory's git repo.

# polly sh

exec's into the polly controller deployement to provide a debugging interactive tty

# polly logs

prints logs of polly controller deployement for debugging

# wkndr key

TBD: manages authentication

# wkndr gitch

TBD: useful gitflow utilities

# polly continuous

TBD: internal process for looping

# polly watch

the `watch` command facilitates local CI workfow or C.T.R. style development practices

    #TODO polly watch
