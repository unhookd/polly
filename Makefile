install:
	bundle config set --local path 'vendor/bundle'
	bundle install
	sudo ln -fs $(HOME)/workspace/polly/bin/polly /usr/local/bin/polly
	polly help
