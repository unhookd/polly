install:
	bundle install --path=vendor/bundle
	sudo ln -fs $(HOME)/workspace/polly/bin/polly /usr/local/bin/polly
	polly help
