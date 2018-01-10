# data-fingerprints
Software for creating and comparing data fingerprints: locality-sensitive hashing of arbitrary data in JSON or XML format.  

1. To create a fingerprint for a a collection of JSON objects:  
	`bin/LPH_multiple_JSON.pl` _directory fingerprintLength normalize_  
	...will generate fingerprints for all JSON objects in _directory_  

2. To create a fingerprint for a a collection of XML files:  
	`bin/LPH_multiple_XML.pl` _directory fingerprintLength normalize_  
	...will generate fingerprints for all XML files in _directory_  

3. To serialize fingerprints into a database:  
	`bin/serializeLPH.pl` _myFingerprintCollection fingerprintLength columnsToIgnore normalize @myListOfFingerprints_  
	`bin/serializeLPH.pl` _myFingerprintCollection fingerprintLength columnsToIgnore normalize *.outn.gz_

4. To compare a fingerprint to a database:  
	`bin/searchLPHs.pl` _myGenome.outn.gz myFingerprintCollection_  

5. To compare two databases:  
	`bin/searchLPHs.pl` _aFingerprintCollection anotherFingerprintCollection_

6. To perform all-against-all comparisons in one database:  
	`bin/searchLPHs.pl` _aFingerprintCollection_

This project is conceptually related to (but distinct from) the Genome Fingerprints: https://github.com/gglusman/genome-fingerprints

