#!/bin/bash -l

# source parameters
if [ -f "${HOME}/.cellsim_test.conf" ]; then
    source ${HOME}/.cellsim_test.conf
fi

# check parameters are set, otherwise use defaults
if [ -z "${mailto}" ]; then
    mailto=""
fi
if [ -z "${testrundir}" ]; then
    testrundir="${HOME}/.cache/cellsim_test"
fi

# path to slurm submit script
scriptdir=$(cd "${BASH_SOURCE%/*}" > /dev/null; pwd)
slurmscript="${scriptdir}/run_test.sl"
echo "Path to slurm script: '${slurmscript}'"
if [ ! -f "${slurmscript}" ]; then
    >&2 echo "Error: path to slurm script wrong: '${slurmscript}'!"
    exit 1
fi

# create/clear test directory and make sure we have the absolute path
mkdir -p "${testrundir}"
rm "${testrundir}"/*
rundir=$(cd "${testrundir}" > /dev/null; pwd)

# echo some settings
echo "Email recipients: '${mailto}'"
echo "Test run directory: '${rundir}'"

# change to run dir
echo "Changing to run dir"
cd "${rundir}"

# submit test script
echo "Submitting batch job..."
jobid=$(sbatch "${slurmscript}" | awk '{print $4}')
echo "Job ID is ${jobid}"

# wait for job to complete
echo "Waiting for job ${jobid} to complete..."
sleep 10
while squeue -u ${USER} | grep ${jobid}; do sleep 60; done

# check results
[ ! -f result_1.txt ] && echo "Failure for generic3d_03_pan_vcl-serial-intel" > result_1.txt
[ ! -f result_2.txt ] && echo "Failure for generic3d_04_pan_vcl-serial-intel" > result_2.txt
[ ! -f result_3.txt ] && echo "Failure for generic3d_03_pan_vcl-cuda-gnu" > result_3.txt
[ ! -f result_4.txt ] && echo "Failure for generic3d_04_pan_vcl-cuda-gnu" > result_4.txt
[ ! -f result_5.txt ] && echo "Failure for generic3d_03_pan_mkl-intel" > result_5.txt
[ ! -f result_6.txt ] && echo "Failure for generic3d_04_pan_mkl-intel" > result_6.txt
results=$(cat result_*.txt)

# the outcome
if grep "Failure" result_*.txt; then
    outcome="Failure"
else
    outcome="Success"
fi
echo "Outcome is ${outcome}"

# send email if required
if [ -z "${mailto}" ]; then
    exit 0
fi

echo "Sending email..."
cat <<EOF | mail -t -a slurm-${jobid}_1.txt -a slurm-${jobid}_2.txt -a slurm-${jobid}_3.txt -a slurm-${jobid}_4.txt -a slurm-${jobid}_5.txt -a slurm-${jobid}_6.txt
To: ${mailto}
Subject: Test of cellsim_34_vcl on pan: ${outcome}

Outcome of test on $(date): ${outcome}.

${results}

EOF
