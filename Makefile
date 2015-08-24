SHORT_CMD=bklr bklc bklv bklb bkhv bkec bkmap bksc bkmonitor
LONG_CMD=halt_a_vm launch_a_command launch_a_run launch_a_vm launch_benchmark export_config scheduler
LIB_SCRIPT=lib/benchkit.lib.sh
TARGET="$(HOME)"

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
