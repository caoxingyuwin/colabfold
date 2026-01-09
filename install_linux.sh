#!/bin/bash -e

type wget 2>/dev/null || { echo "wget is not installed. Please install it using apt or yum." ; exit 1 ; }

CURRENTPATH="$(pwd)"
COLABFOLDDIR="${CURRENTPATH}/localcolabfold"

mkdir -p "${COLABFOLDDIR}"
cd "${COLABFOLDDIR}"

# ----------------------------------------------------------------------
# Install Miniforge
# ----------------------------------------------------------------------
wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash ./Miniforge3-Linux-x86_64.sh -b -p "${COLABFOLDDIR}/conda"
rm Miniforge3-Linux-x86_64.sh

# Init conda
source "${COLABFOLDDIR}/conda/etc/profile.d/conda.sh"
export PATH="${COLABFOLDDIR}/conda/condabin:${PATH}"

conda update -n base conda -y

# ----------------------------------------------------------------------
# Create conda env (name shown in `conda env list`)
# ----------------------------------------------------------------------
conda create -n colabfold -c conda-forge -c bioconda \
    git \
    python=3.10 \
    openmm==8.2.0 \
    pdbfixer \
    kalign2=2.04 \
    hhsuite=3.3.0 \
    mmseqs2 \
    -y

conda activate colabfold

# ----------------------------------------------------------------------
# Install ColabFold & dependencies
# ----------------------------------------------------------------------
pip install --no-warn-conflicts \
    "colabfold[alphafold-minus-jax] @ git+https://github.com/sokrypton/ColabFold"

pip install "colabfold[alphafold]"
pip install --upgrade "jax[cuda12]==0.5.3"
pip install --upgrade tensorflow
pip install silence_tensorflow

# ----------------------------------------------------------------------
# Download updater
# ----------------------------------------------------------------------
wget -qnc -O "${COLABFOLDDIR}/update_linux.sh" \
    https://raw.githubusercontent.com/YoshitakaMo/localcolabfold/main/update_linux.sh
chmod +x "${COLABFOLDDIR}/update_linux.sh"

# ----------------------------------------------------------------------
# Patch ColabFold source
# ----------------------------------------------------------------------
COLABFOLD_SITE=$(python - << 'EOF'
import site
print(site.getsitepackages()[0])
EOF
)

pushd "${COLABFOLD_SITE}/colabfold"

# non-GUI backend
sed -i -e \
"s#from matplotlib import pyplot as plt#import matplotlib\nmatplotlib.use('Agg')\nimport matplotlib.pyplot as plt#g" \
plot.py

# cache directory
sed -i -e \
"s#appdirs.user_cache_dir(__package__ or \"colabfold\")#\"${COLABFOLDDIR}/colabfold\"#g" \
download.py

# silence tensorflow
sed -i -e \
"s#from io import StringIO#from io import StringIO\nfrom silence_tensorflow import silence_tensorflow\nsilence_tensorflow()#g" \
batch.py

rm -rf __pycache__
popd

# ----------------------------------------------------------------------
# Download AlphaFold weights
# ----------------------------------------------------------------------
python -m colabfold.download

# ----------------------------------------------------------------------
# Finish
# ----------------------------------------------------------------------
echo "-----------------------------------------"
echo "Installation of ColabFold finished."
echo
echo "Conda environment name: colabfold"
echo "Activate with:"
echo "  source ${COLABFOLDDIR}/conda/etc/profile.d/conda.sh"
echo "  conda activate colabfold"
echo
echo "Check with:"
echo "  conda env list"
echo "-----------------------------------------"
