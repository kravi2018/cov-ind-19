#!/bin/bash

#SBATCH --mail-type=FAIL,ARRAY_TASKS
#SBATCH --time=10:00
#SBATCH --job-name=git_commit_and_push_prediction_data
#SBATCH --mem-per-cpu=1G
#SBATCH --output=/home/%u/slurm_output/slurm-%A_%a.out
#SBATCH --account=covid19_project1
#SBATCH --partition=standard

export http_proxy=http://proxy.arc-ts.umich.edu:3128/
export FTP_PROXY=http://proxy.arc-ts.umich.edu:3128/
export ftp_proxy=http://proxy.arc-ts.umich.edu:3128/
export HTTPS_PROXY=http://proxy.arc-ts.umich.edu:3128/
export https_proxy=http://proxy.arc-ts.umich.edu:3128/
export HTTP_PROXY=http://proxy.arc-ts.umich.edu:3128/



# Set variables based on testing or production
if [[ $production == "TRUE" ]]
then
    export data_repo="$HOME/cov-ind-19-data"
else
    export data_repo="$HOME/cov-ind-19-test"
fi

cd $data_repo/$today/
git add *
git commit -m "Automated push from slurm job"
git push
