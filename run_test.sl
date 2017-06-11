#!/bin/bash -l
#SBATCH -J cellsim_test
#SBATCH -A nesi00119          # Project Account
#SBATCH --time=0:59:00        # Walltime HH:MM:SS
#SBATCH --mem-per-cpu=2G     # Memory
#SBATCH --ntasks=1            # number of tasks
#SBATCH --cpus-per-task=1     # number of threads
#SBATCH --output=slurm-%A_%a.txt
#SBATCH --error=slurm-%A_%a.txt
#SBATCH --gres=gpu:1
#SBATCH --array=1-6

# load modules
module purge
module load CMake/3.6.1
module load Python/3.5.1-intel-2015a

# repo
repo="https://github.com/jrugis/cellsim_34_vcl.git"
repodir=$(basename "${repo}" | cut -d'.' -f1)

# list of tests
tests[1]="generic3d_03_pan_vcl-serial-intel"
tests[2]="generic3d_04_pan_vcl-serial-intel"
tests[3]="generic3d_03_pan_vcl-cuda-intel"
tests[4]="generic3d_04_pan_vcl-cuda-intel"
tests[5]="generic3d_03_pan_mkl-intel"
tests[6]="generic3d_04_pan_mkl-intel"
echo "Running test for cellsim_34_vcl: ${tests[$SLURM_ARRAY_TASK_ID]}"

# list of cmake args corresponding to above
cmakeargs[1]="-DFOUR_VARIABLES=OFF -DCMAKE_BUILD_TYPE=RELEASEPAN -DTEST_PYTHON_REDUCE=OFF"
cmakeargs[2]="-DTHREE_VARIABLES=OFF -DCMAKE_BUILD_TYPE=RELEASEPAN -DTEST_PYTHON_REDUCE=OFF"
cmakeargs[3]="-DBUILD_SERIAL=OFF -DBUILD_CUDA=ON -DFOUR_VARIABLES=OFF -DCMAKE_BUILD_TYPE=RELEASE -DTEST_PYTHON_REDUCE=OFF"
cmakeargs[4]="-DBUILD_SERIAL=OFF -DBUILD_CUDA=ON -DTHREE_VARIABLES=OFF -DCMAKE_BUILD_TYPE=RELEASE -DTEST_PYTHON_REDUCE=OFF"
cmakeargs[5]="-DBUILD_SERIAL=OFF -DBUILD_MKL=ON -DFOUR_VARIABLES=OFF -DCMAKE_BUILD_TYPE=RELEASEPAN -DTEST_PYTHON_REDUCE=OFF"
cmakeargs[6]="-DBUILD_SERIAL=OFF -DBUILD_MKL=ON -DTHREE_VARIABLES=OFF -DCMAKE_BUILD_TYPE=RELEASEPAN -DTEST_PYTHON_REDUCE=OFF"

# working dir for this process
resultdir=$(pwd)
workdir="${SCRATCH_DIR}/${SLURM_ARRAY_TASK_ID}_${tests[$SLURM_ARRAY_TASK_ID]}"
echo "Switching to working dir: ${workdir}"
mkdir "${workdir}"
cd "${workdir}"

# clone repo
if ! srun git clone "${repo}"
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
srun cmake -DCMAKE_CXX_COMPILER=icpc ${cmakeargs[$SLURM_ARRAY_TASK_ID]} ..

# compile code
echo "Compiling..."
srun make

# run the code
echo "Running test..."

# compare the result
if srun ctest --output-on-failure
then
    echo "Test succeeded"
    outcome="Success for ${tests[$SLURM_ARRAY_TASK_ID]}"
else
    echo "Test failed"
    outcome="Failure for ${tests[$SLURM_ARRAY_TASK_ID]}"
fi

# write output file
echo ${outcome} > "${resultdir}/result_${SLURM_ARRAY_TASK_ID}.txt"
