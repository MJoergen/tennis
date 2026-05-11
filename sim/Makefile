DUTS += tb_unit_vector
DUTS += tb_collision
DUTS += tb_tennis

DUT_PASS   = $(patsubst %,%/PASS,$(DUTS))

all: $(DUT_PASS)

%/PASS: DUT=$(patsubst %/PASS,%,$@)
%/PASS:
	$(MAKE) -C $(DUT)

clean:
	for i in $(DUTS); do $(MAKE) -C $$i clean; done

