# data-fingerprints
Software for creating and comparing data fingerprints: locality-sensitive hashing of semi-structured data in JSON or XML format.  
More information and datasets: http://db.systemsbiology.net/gestalt/data_fingerprints/  
Preprint: https://www.biorxiv.org/content/early/2018/04/02/293183  

1. Create fingerprints. L is the desired fingerprint length.  
	a. From a a collection of JSON objects (one per file in a directory):  
	`bin/LPH_multiple_JSON.pl` _directory L [normalize]_ > collection  
	b. From a collection of XML files (one per file in a directory):  
	`bin/LPH_multiple_XML.pl` _directory L [normalize]_ > collection  
	c. From a a collection of JSON objects (in one file):  
	`bin/LPH_JSON.pl` _file idField L [normalize]_ > collection  
	d. From a collection of XML objects (in one file):  
	`bin/LPH_XML.pl` _file idField L [normalize]_ > collection  
	e. From a stream of JSON objects one-per-line (as in Wikidata):  
	`bin/LPH_linewise_JSON.pl` _file idField L [normalize]_ > collection

2. Visualize. Example R code, where L is your fingerprint length:  
	```
	data <- read.table("collection", header=FALSE)  
	M <- as.matrix(data[,2 + 1:L])  
	pca <- prcomp(M, center=TRUE, scale.=TRUE)  
	mag=c(sqrt(data[,2])/50)  
	col=c(rep(grey(0,.5), length(data[,1])))  
	plot(pca$x[,1], pca$x[,2], pch=20, cex=mag, col=col, xlab='PC1', ylab='PC2')
	
	require(Rtsne)
	tsne <- Rtsne(data[,2 + 1:L], dims=2, perplexity=50, verbose=TRUE, max_iter=500)
	plot(tsne$Y, main='tsne', pch=20, cex=mag, col=col)
	```

3. Serialize fingerprints into a database.  
	`bin/serializeLPH.pl` _collection L columnsToIgnore normalize @listOfFingerprints_  
	`bin/serializeLPH.pl` _collection L columnsToIgnore normalize *.outn.gz_

4. [TBD] Compare two databases.  
	`bin/searchLPHs.pl` _collection anotherCollection_

5. [TBD] Perform all-against-all comparisons in one database.  
	`bin/searchLPHs.pl` _collection_

This project is conceptually related to (but distinct from) the Genome Fingerprints: https://github.com/gglusman/genome-fingerprints

