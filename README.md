# polly - a gitops native, single tenant, micro ci laboratory

polly can be used to debug several types of ci platforms

# .circleci/config.yml

polly understands circleci config and is able to plan and execute workflows on a local or remote kubernetes cluster

# installation

    cd ~/workspace
    git clone git@github.com:unhookd/polly.git
    cd polly
    make install #NOTE: will prompt for sudo password

# general workflow

    cd ~/workspace/myproj
    polly build # build polly controller Dockerfile
    polly init # install polly controller into desired kubernetes context

    cd ~/workspace/myproj
    git status # polly requires a valid git repo to work

    polly push # install current PWD as a project in the deployed polly controller

    polly test --dry-run # emit plan for execution for detected ci workflow

    polly test # execute detected ci workflows

    # iterate on your project by creating new commit SHAs

    polly push && polly test

    # TODO: bonus

    polly watch

# development workflow

    cd ~/workspace/myproj
    cat Procfile # ensure you have a Procfile present, see below for example

      # example Procfile
      one: sleep 5 && echo true
      two: sleep 2 && echo false

    polly dev # will run commands in Procfile
