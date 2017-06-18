SHORT_CMD=bklr bklc bklv bklb bkhv bkec bkmap bksc bkmonitor
LONG_CMD=halt_a_vm launch_a_command launch_a_run launch_a_vm launch_benchmark export_config scheduler
LIB_SCRIPT=lib/benchkit.lib.sh
TARGET="$(HOME)"

doc:
	@echo "================================================================================"
	@echo " BenchKit version 2 (2016)"
	@echo " F. Kordon and F. Hulin-Hubard"
	@echo "================================================================================"
	@echo
	@echo "Possibles options are:"
	@echo
	@echo " - install     : generate links for an easy access to all BenchKit commands"
	@echo " - long        : same as install but with long command names"
	@echo " - uninstall   : uninstall BenchKit (delete links)"
	@echo " - clean       : same as uninstall"
	@echo " - distrib     : build a distribution"
	@echo " - selfdistrib : same as distrib but in a location defined with variable where"

install:
	for link in $(SHORT_CMD) ; do \
		ln -s $(LIB_SCRIPT) $$link ; \
	done
	chmod 600 conf/bk-private_key

long:
	for link in $(LONG_CMD) ; do \
		ln -s $(LIB_SCRIPT) $$link ; \
	done
	chmod 600 conf/bk-private_key

uninstall:
	for link in $(LONG_CMD) $(SHORT_CMD) ; do \
		rm $$link ; \
	done

clean: uninstall

distrib:
	mkdir "$(TARGET)/BenchKit2"
	cp -r lib conf Makefile "$(TARGET)/BenchKit2"
	bash -c 'cd "$(TARGET)" ; export COPYFILE_DISABLE=true; tar czf BenchKit2.tgz BenchKit2'
ifeq ($(USER),fko)
	mv $(TARGET)/BenchKit2.tgz $(TARGET)/Desktop/BenchKit2.tgz 
	mv $(TARGET)/BenchKit2 $(TARGET)/Desktop/BenchKit2
endif

selfdistrib:
	mkdir "$(where)/BenchKit2"
	cp -r lib conf Makefile "$(where)/BenchKit2"
	bash -c 'cd "$(where)" ; export COPYFILE_DISABLE=true; tar czf BenchKit2.tgz BenchKit2'
