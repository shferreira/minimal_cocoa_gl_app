FRAMEWORKS = Cocoa IOKit OpenGL
CCOPTS = -fmodules -O3 -Wall -pedantic -Wno-deprecated-declarations

main: main.m
	$(CC) $(CCOPTS) $(addprefix -framework ,$(FRAMEWORKS)) $< -o $@
