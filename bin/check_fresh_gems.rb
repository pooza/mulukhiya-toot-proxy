#!/usr/bin/env ruby

system('bundle', 'update')
exit 1 if `git status`.include?('Gemfile.lock')
exit 1 if `git status`.include?('cacert.pem')
