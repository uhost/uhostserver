uhostserver
===========

Install
-------

wget https://getuhost.s3-us-west-2.amazonaws.com/installserver.sh

sudo sh ./installserver.sh -n <site name>

Testing
-------

Install [vagrant](http://docs.vagrantup.com/v2/installation/)

use local virtualbox

vagrant up local
vagrant ssh local

use aws

vagrant up aws --provider=aws
vagrant ssh aws

Edit your hosts file so that 33.33.33.10 points to localtest.getuhost.org and chef.localtest.getuhost.org

Development
-----------
This application uses Test Kitchen (1.0). To run the tests, clone the repository, install the gems, and run test kitchen:

    $ git clone git://github.com/uhost/uhostserver.git
    $ cd uhostserver
    $ bundle install
    $ bundle exec strainer test

1. Fork the cookbook on GitHub
2. Make changes
3. Write appropriate tests
4. Submit a Pull Request back to the project
5. Open a [JIRA ticket](https://tickets.opscode.com), linking back to the Pull Request


License & Authors
-----------------
- Author:: Mark Allen (mark@markcallen.com)

Copyright:: 2015, Mark C Allen Software Inc. 

Add License Info
