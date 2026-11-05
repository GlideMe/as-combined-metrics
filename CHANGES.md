1.0.0
initial release
1.1.0
Be able to to have spot fleets monitored
1.1.1
require fileutils for use with ruby 2.6.8
1.2.0
A spot fleet deployed one fleet per subnet (<logical id><subnet suffix>) is found by its logical id prefix, and the instances of every fleet count in the combined metric
1.2.1
The per-subnet fleets are read with DescribeStackResources, which the instance roles allow (ListStackResources only for a stack of more than 100 resources)
1.2.2
The config file records which logical resource ids are resolved, and every id not yet resolved is looked up at start, also when another one already is (a config left by 1.1.1 with the autoscale group but no fleets now gets its fleets); README lists ListStackResources
