# polly - a gitops native, single tenant, micro ci laboratory

A choose your own adventure git+ops authenticated journaled deployment controller development pipeline kubernetes utility test service.

`polly` uses the basename of the current "working directory" ($PWD) as a source of information on conventional pipelines.

There are also the notion of the `polly` deployment "itself", known as `$POLLY`.

polly can be used to debug several types of ci platforms, to facilitate local CI, and as a general purpose dev tool.

# safety instructions

Do not expose polly to a kubernetes cluster unless you have thoroughly understood the risk.

# installation

TODO, in the future, `polly` will be available via `sudo gem install polly` ... until then it must be installed manually, see below

    sudo apt-get install ruby rubygems-integration libffi-dev build-essential --no-install-recommends
    sudo gem install bundler
    cd ~/workspace
    git clone git@github.com:unhookd/polly.git
    cd polly
    bundle config set --local path vendor/bundle
    bundle install
    sudo ln -fs ${HOME}/workspace/polly/bin/polly /usr/local/bin/polly
    polly help

# .circleci/config.yml

polly understands circleci config and is able to plan and execute workflows on a local or remote kubernetes cluster


TBD: rebake this bootstrap script into github actions as test-suite cross-check

# initial polly deploy to local kubeadm cluster

We can re-bootstrap `polly` from scratch for development purposes, or just start in a given project directory

    cd ~/workspace/myproj
    polly build # build polly controller Dockerfile

# polly init

Install the `polly` controller into your kube cluster.

    kubectx
    polly init
    
should install `polly` controller into desired kubernetes context

# polly push

the `push` command will push the git repo from `$PWD` to the polly controller

_requires_ `$PATH/git` to be present.

begins pipeline by sending latest commits to git remote controller

git remote controller will process inbound commits via `git-receive-pack`

current local branch will be stored into bare repo

polly requires a valid git repo to work, and includes event hooks that are dispatched

    cd ~/workspace/myproj
    git status
    polly push

installs a copy of the current PWD as a bare git repo checkout in the deployed `polly` controller

# polly changelog

the `polly changelog` command is a tool that appends to development journal CHANGELOG.md by default.

Useful for creating notes, or making blank commits for pushing into a git+ops pipeline

It can also be used to increment a VERSION file

# polly version

prints current polly version

# polly test

the `test` command will run the auto-detected workflow (currently supports `Pollyfile` and `.circleci/config.yml` declared suites)

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

The output is multiplexed and highlight on a per-process basis, this makes it useful for a variety of debugging uses.

# polly build

build `$APP:latest` using the the detected packaging system, `Pollyfile` and `Dockerfile` are automatically detected, from the HEAD version of the current working directory's git repo.

# polly sh

exec's into the polly controller deployement to provide a debugging interactive tty

# polly logs

prints logs of polly controller deployement for debugging

# polly docker-config

accepts on STDIN a `~/.docker/config.json` document, and creates a specific secret for allowin fetching from private repos in private clusters.

TBD: allow STDIN creation of a variety of configMap/secretMap resources (SEE: `polly certificate`)

# polly key

TBD: manages authentication

# polly gitch

TBD: useful gitflow utilities


# polly continuous

TBD: internal process for looping

```
  while true
    polly gitch -m -u
```

# polly tcr / ctr

the `watch` command facilitates local CI workfow or T.C.R. style development practices

    #TODO polly tcr

# polly prototype1

#TODO
#kubectl delete -f kubernetes --wait=false || true
#
#polly build
#
#kubectl delete -f kubernetes || true
#kubectl delete pod binlogik --wait || true
#
#kubectl apply -f kubernetes
#
#cleanup() {
#  echo -n " ... please wait ... "
#  kubectl delete pod binlogik
#  exit
#}
#
#trap cleanup INT TERM
#
#while ! kubectl logs binlogik -c binlogik -f --pod-running-timeout=60s
#do
#  sleep 1
#  echo -n ","
#done

# prototypez

#TODO: list known prototypical workflows
