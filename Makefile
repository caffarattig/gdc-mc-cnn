PREFIX=$(HOME)/torch/install
CUDA=/usr/local/cuda-8.0
CFLAGS=-I$(PREFIX)/include/THC -I$(PREFIX)/include/TH -I$(PREFIX)/include
LDFLAGS_NVCC=-L$(PREFIX)/lib -Xlinker -rpath,$(PREFIX)/lib -lluaT -lTHC -lTH -lpng
LDFLAGS_CPP=-L$(PREFIX)/lib -lluaT -lTH `pkg-config --libs opencv`
LDFLAGS_NPP=-L$(CUDA)/lib64 -lnppim

all: libcuresmatch.so libadcensus.so libcustomcv.so libgdcutils.so

libadcensus.so: src/adcensus.cu
	$(CUDA)/bin/nvcc -arch sm_35 -O3 -DNDEBUG --compiler-options '-fPIC' -o libadcensus.so --shared src/adcensus.cu $(CFLAGS) $(LDFLAGS_NVCC)

libcuresmatch.so: src/curesmatch.cu
	$(CUDA)/bin/nvcc -arch sm_35 -O3 -DNDEBUG --compiler-options '-fPIC' -o libcuresmatch.so --shared src/curesmatch.cu $(CFLAGS) $(LDFLAGS_NVCC)
	
libgdcutils.so: src/gdcutils.cu
	$(CUDA)/bin/nvcc -arch sm_35 -O3 -DNDEBUG --compiler-options '-fPIC' -o libgdcutils.so --shared src/gdcutils.cu $(CFLAGS) $(LDFLAGS_NVCC) $(LDFLAGS_NPP)

libcustomcv.so: src/customcv.cpp
	g++ -fPIC -o libcustomcv.so -shared src/customcv.cpp $(CFLAGS) $(LDFLAGS_CPP)

clean:
	rm -f libcuresmatch.so libadcensus.so libcustomcv.so libgdcutils.so
