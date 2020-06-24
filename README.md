This is a repository for R packages constructed using 
[drat](http://dirk.eddelbuettel.com/code/drat.html).

This allows R `DESCRIPTION` files to access packages that are not available on CRAN using
 
`Additional_repositories: https://ms609.github.io/packages`

Add packages using
```r
drat::insertPackage('path/to/PACKAGENAME_1.0.0.tar.gz', 'path/to/packages')
```
