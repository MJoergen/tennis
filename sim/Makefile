DUTS += tb_ball
DUTS += tb_collision
DUTS += tb_tennis
DUTS += tb_unit_vector

DUT_PASS   = $(patsubst %,%/PASS,$(DUTS))

all: $(DUT_PASS)

%/PASS: DUT=$(patsubst %/PASS,%,$@)
%/PASS:
	$(MAKE) -C $(DUT)

clean:
	for i in $(DUTS); do $(MAKE) -C $$i clean; done

