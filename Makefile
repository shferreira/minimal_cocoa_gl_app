all:
	@clang -Wall -pedantic -framework CoreAudio -framework Cocoa -framework OpenGL -framework CoreVideo -framework AudioUnit -framework IOKit mac.m -o main
	@./main
	@rm ./main
