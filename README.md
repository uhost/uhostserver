uhostserver
===========

Install
-------

````
wget https://raw.githubusercontent.com/uhost/uhostserver/master/installserver.sh

sudo bash ./installserver.sh -n <site name>
````

Testing
-------

Install [vagrant](http://docs.vagrantup.com/v2/installation/)

use local virtualbox

````
vagrant up local
vagrant ssh local
````

use aws

````
vagrant up aws --provider=aws
vagrant ssh aws
````

Edit your hosts file so that 33.33.33.10 points to localtest.getuhost.org and chef.localtest.getuhost.org

Development
-----------

    $ git clone git://github.com/uhost/uhostserver.git
    $ cd uhostserver
    $ bundle install

1. Fork the cookbook on GitHub
2. Make changes
3. Write appropriate tests
4. Submit a Pull Request back to the project


License & Authors
-----------------
- Author:: Mark Allen (mark@markcallen.com)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
