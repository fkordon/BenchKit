
##### pour la machine quadhexa de nanterre (tests)
./bklb -deploy -disk_images testquadhexa.bkjobs /Users/fko/Downloads/VM-MCC2014 

./bklb -generate testquadhexa quadhexa-2.u-paris10.fr 4 fko 300 2048 4 mcc mcc-conf/tools_all.txt mcc-conf/models_first_known.txt mcc-conf/examinations_all.txt /home/fko
./bklb -deploy -benchkit testquadhexa.bkjobs
./bklb -execute testquadhexa.bkjobs fabrice.kordon@lip6.fr

./bkmonitor -continuous testquadhexa.bkjobs 3
