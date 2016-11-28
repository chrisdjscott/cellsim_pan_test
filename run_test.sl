#!/bin/bash -l
#SBATCH -J cellsim_test
#SBATCH -A nesi00119          # Project Account
#SBATCH --time=0:15:00        # Walltime HH:MM:SS
#SBATCH --mem-per-cpu=2G     # Memory
#SBATCH --ntasks=1            # number of tasks
#SBATCH --cpus-per-task=1     # number of threads
#SBATCH --output=slurm-%A_%a.txt
#SBATCH --error=slurm-%A_%a.txt
#SBATCH --gres=gpu:1
#SBATCH --array=1-6

# load modules
module purge
module load CMake/3.4.1-GCC-4.9.2
module load Python/3.5.1-intel-2015a

# repo
repo="https://github.com/jrugis/cellsim_34_vcl.git"
repodir=$(basename "${repo}" | cut -d'.' -f1)

# list of tests
tests[1]="generic3d_03_pan_vcl-serial-intel"
tests[2]="generic3d_04_pan_vcl-serial-intel"
tests[3]="generic3d_03_pan_vcl-cuda-gnu"
tests[4]="generic3d_04_pan_vcl-cuda-gnu"
tests[5]="generic3d_03_pan_mkl-intel"
tests[6]="generic3d_04_pan_mkl-intel"
echo "Running test for cellsim_34_vcl: ${tests[$SLURM_ARRAY_TASK_ID]}"

# list of cmake args corresponding to above
cmakeargs[1]="-DFOUR_VARIABLES=OFF -DCMAKE_BUILD_TYPE=RELEASEPAN"
cmakeargs[2]="-DTHREE_VARIABLES=OFF -DCMAKE_BUILD_TYPE=RELEASEPAN"
cmakeargs[3]="-DBUILD_SERIAL=OFF -DBUILD_CUDA=ON -DFOUR_VARIABLES=OFF -DCMAKE_BUILD_TYPE=RELEASE"
cmakeargs[4]="-DBUILD_SERIAL=OFF -DBUILD_CUDA=ON -DTHREE_VARIABLES=OFF -DCMAKE_BUILD_TYPE=RELEASE"
cmakeargs[5]="-DBUILD_SERIAL=OFF -DBUILD_MKL=ON -DFOUR_VARIABLES=OFF -DCMAKE_BUILD_TYPE=RELEASEPAN"
cmakeargs[6]="-DBUILD_SERIAL=OFF -DBUILD_MKL=ON -DTHREE_VARIABLES=OFF -DCMAKE_BUILD_TYPE=RELEASEPAN"

# working dir for this process
workdir="${SLURM_ARRAY_TASK_ID}_${tests[$SLURM_ARRAY_TASK_ID]}"
echo "Switching to working dir: ${workdir}"
mkdir "${workdir}"
cd "${workdir}"

# clone repo
if ! git clone "${repo}"
then
    echo "Failed to clone repo!"
    exit 1
fi


# switch to build dir
cd "${repodir}"
mkdir build
cd build

# run cmake
echo "Running cmake..."
if echo ${tests[$SLURM_ARRAY_TASK_ID]} | grep cuda
then
    CXX=g++ cmake .. ${cmakeargs[$SLURM_ARRAY_TASK_ID]}
else
    CXX=icpc cmake .. ${cmakeargs[$SLURM_ARRAY_TASK_ID]}
fi

# compile code
echo "Compiling..."
make

# test dir
cd ../test

# prepare to run the test
echo "Preparing to run test..."
cp -f cell01m_HARMONIC_100p.msh cs.msh
if echo ${tests[$SLURM_ARRAY_TASK_ID]} | grep "_03"
then
    cp -f generic3d_03-cs.dat cs.dat
else
    cp -f generic3d_04-cs.dat cs.dat
fi

# run the code
echo "Running test..."
srun ../build/${tests[$SLURM_ARRAY_TASK_ID]}

# compare the result
if python cs_compare_peaks.py cR.bin generic3d-cR.bin
then
    echo "Binary output files match"
    outcome="Success for ${tests[$SLURM_ARRAY_TASK_ID]}"
else
    # if the binary files did not match, run the python script to see how big the difference was
    outcome="Failure for ${tests[$SLURM_ARRAY_TASK_ID]}"
fi

# write output file
echo ${outcome} > "../../../result_${SLURM_ARRAY_TASK_ID}.txt"
