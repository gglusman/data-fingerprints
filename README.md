# data-fingerprints
Software for creating and comparing data fingerprints: locality-sensitive hashing of arbitrary data in JSON or XML format.  

1. Create fingerprints:  
	a. From a a collection of JSON objects:  
	`bin/LPH_multiple_JSON.pl` _directory fingerprintLength normalize_ > collection  
	b. From a collection of XML files:  
	`bin/LPH_multiple_XML.pl` _directory fingerprintLength normalize_ > collection

2. Visualize:  
	Example R code, where L is your fingerprint length:  
	```
	data <- read.table("collection", header=FALSE)  
	M <- as.matrix(data[,3:L+2])  
	pca <- prcomp(M, center=TRUE, scale.=TRUE)  
	mag=c(sqrt(data[,2])/50)  
	col=c(rep(grey(0,.5), length(data[,1])))  
	plot(pca$x[,1], pca$x[,2], pch=20, cex=mag, col=col, xlab='PC1', ylab='PC2')
	
	require(Rtsne)
	tsne <- Rtsne(data[,3:L+2], dims=2, perplexity=50, verbose=TRUE, max_iter=500)
	plot(tsne$Y, main='tsne', pch=20, cex=mag, col=col)
	```

3. Serialize fingerprints into a database:  
	`bin/serializeLPH.pl` _collection fingerprintLength columnsToIgnore normalize @myListOfFingerprints_  
	`bin/serializeLPH.pl` _collection fingerprintLength columnsToIgnore normalize *.outn.gz_

4. [TBD] Compare a fingerprint to a database:  
	`bin/searchLPHs.pl` _myFingerprint.outn.gz collection_  

5. [TBD] Compare two databases:  
	`bin/searchLPHs.pl` _aFingerprintCollection anotherCollection_

6. [TBD] Perform all-against-all comparisons in one database:  
	`bin/searchLPHs.pl` _collection_

This project is conceptually related to (but distinct from) the Genome Fingerprints: https://github.com/gglusman/genome-fingerprints

