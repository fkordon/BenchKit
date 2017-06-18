# BenchKit
BenchKit is a Tool for Massive Concurrent Benchmarking

For more details, please have a look at :

http://lip6.fr/Fabrice.Kordon/pdf/2014-ACSD.pdf

The presentation corresponding to this paper (27 minutes) can also be viewed here:

http://youtu.be/askrJAqDV74

type "make" to get a minimal documentation about packaging and installing

type "make -f mcc-conf/Makefile-runs" to get a minimal documentation
about te use of BenchKit:
1) deployment,
2) execution and retrieving of results.

Some elements must be configured but mcc-conf/Makefile-runs gives some 
hints.

The soft to be packaged must be provided in a virtual machine (via a disk image).
The execution machine must have qemu/KVM installed.
