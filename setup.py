import sys
sys.path.append('../../')

import setuptools

with open("README.md", "r") as fh:
    long_description = fh.read()

setuptools.setup(
    name="datafingerprint",
    version="0.0.1",
    author="Gustavo Glusman",
    author_email="gglusman@isbscience.org",
    description="Software for creating and comparing data fingerprints: locality-sensitive hashing of semi-structured data in JSON or XML format.",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/gglusman/data-fingerprints",
    packages=setuptools.find_packages(),
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    python_requires='>=3.6',
)