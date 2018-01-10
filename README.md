# data-fingerprints
Software for creating and comparing data fingerprints: locality-sensitive hashing of arbitrary data in JSON or XML format.  

1. To create a fingerprint for a a collection of JSON objects:  
	`bin/LPH_multiple_JSON.pl` _directory fingerprintLength_  
	...will generate raw fingerprints for all JSON objects in _directory_  
	`bin/LPH_multiple_JSON.pl` _directory fingerprintLength_ 1  
	...will generate normalized fingerprints for all JSON objects in _directory_  

2. To create a fingerprint for a a collection of XML files:  
	`bin/LPH_multiple_XML.pl` _directory fingerprintLength_  
	...will generate raw fingerprints for all XML files in _directory_  
	`bin/LPH_multiple_XML.pl` _directory fingerprintLength_ 1  
	...will generate normalized fingerprints for all XML files in _directory_  

3. To serialize fingerprints into a database:  
	`bin/binarizeLPH.pl` _myFingerprintCollection_ 120 _@myListOfFingerprints_  
	`bin/binarizeLPH.pl` _myFingerprintCollection_ 120 _*.outn.gz_

4. To compare a fingerprint to a database:  
	`bin/searchDMFs.pl` _myGenome.outn.gz myFingerprintCollection_  
	...see the data directory for an example database (CEPH1463 pedigree)

5. To compare two databases:  
	`bin/searchDMFs.pl` _aFingerprintCollection anotherFingerprintCollection_

6. To perform all-against-all comparisons in one database:  
	`bin/searchDMFs.pl` _aFingerprintCollection_

This project is conceptually related to (but distinct from) the Genome Fingerprints: https://github.com/gglusman/genome-fingerprints

