lrtest <- function(w.x, w.y, x, y, signed){
  ## w.x, w.y vectors of zeros/ones for expressed or not in each group
  ## x, y vectors of the positive observations (must be of length sum(w.x) and sum(w.y))

  e.x <- sum(w.x)
  e.y <-  sum(w.y)
  n.x <-  length(w.x)
  n.y <-  length(w.y)
  stopifnot(e.x == length(x) && e.y == length(y))
  

  p.0 <- (e.x+e.y)/(n.x + n.y)
  p.x <- e.x/n.x
  p.y <- e.y/n.y

  m0 <-  (sum(x)+sum(y))/(e.x+e.y)
  mu.x <-  mean(x)
  mu.y <-  mean(y)

  Tstar <-  1+e.x*e.y/(e.x+e.y)* (mu.x - mu.y)^2/(sum((mu.x - x)^2) + sum((mu.y-y)^2))

  if(!is.finite(Tstar)){
    Tstar <- 1
  }

  binom <- logProd(e.x, p.0/p.x) +
    logProd(e.y, p.0/p.y) +
      logProd(n.x-e.x, (1-p.0)/(1-p.x)) +
        logProd(n.y-e.y, (1-p.0)/(1-p.y))
  binomsign <- (p.y>p.x)*2 -1

  norm <- -(e.x+e.y)/2 * log(Tstar)
  normsign <- (mu.y>mu.x)*2-1

  logLR <- binom+norm

  maxsign <- c(binomsign, normsign)[which.min(c(binom, norm))]
  resultvec <- c(-2*binom, binomsign, pchisq(-2*binom, 1, lower.tail=F),
                 -2*norm, normsign, pchisq(-2*norm, 1, lower.tail=F),
                 -2*logLR, maxsign, pchisq(-2*logLR, 2, lower.tail=F))
    result <- matrix(resultvec, nrow=3, ncol=3, dimnames=list(metric=c('lrstat', 'direction', 'p.value'), component=c('binom', 'norm', 'comb')))
}

logProd <- function(prod, logand){
  ifelse(prod==0, 0, prod*log(logand))
}


###Below is the correct way to document S4 generics and methods with roxygen2

##' Likelihood Ratio Tests for SingleCellAssays
##'
##' Tests for a change in ET binomial proportion or mean of positive ET
##' @export
##' @docType methods
##' @rdname LRT-methods
setGeneric("LRT",function(sca,comparison,referent,groups,...){
  standardGeneric("LRT")
})



##' @rdname LRT-methods
##' @aliases LRT,SingleCellAssay,character,character,character-method
##' @usage LRT(sca,comparison,referent,groups)
setMethod("LRT",signature=c("SingleCellAssay","character","character","character"),function(sca,comparison,referent,groups,returnall=FALSE){
  lrt(sca,comparison,referent,groups,returnall)
})


lrt <- function(sca, comparison, referent=NULL, groups=NULL, returnall=TRUE){
  if (missing(comparison) || !checkGroups(sca, comparison))
    stop("'comparison' missing or incorrect")
  ## what happens if comparision has length >1?
  
  if(!is.null(groups)){
    checkGroups(sca, groups)
    ## we should check what happens if comparison has a different number of levels 
    scL <- split(sca, groups)
    lapp <- lapply(scL, lrt, comparison=comparison, referent=referent, groups=NULL, returnall=returnall)
    ## fix
    retme<-do.call(rbind, lapp)
    nr<-lapply(lapp,nrow)
    nms<-names(lapp)
    retme<-rename(cbind(retme,groups=factor(do.call(c,lapply(seq_along(nr),function(i)rep(nms[i],nr[i]))))),c(groups=groups))
    return(retme)
  }
  
  probeid <- sca@mapping$geneid
  measure <- sca@mapping$measurement
  
  phenocol <- melt(sca)[[comparison]]
  if(is.factor(phenocol) && is.null(referent)){
   pheno.order <- phenocol
} else{
  pheno.order <- factor(phenocol)
  pheno.order <- relevel(pheno.order, ref=referent)
}
  nlev <- nlevels(pheno.order)

  ssca <- split(cbind(melt(sca)[, c(measure, comparison)], pheno.order), melt(sca)[,probeid])
  
  lrout <- vapply(ssca, FUN.VALUE=array(0, dim=c(nlev-1, 3, 4)), FUN=function(x){
    res <- array(NA, dim=c(nlev-1, 3, 4))
    phenosplit <- split(x[[measure]], x$pheno.order, drop=FALSE)
    unstim <- phenosplit[[1]]
    w.x <- (unstim>0)*1
    x <- unstim[w.x==1]
    
    for(i in seq(from=2, to=nlev)){
    stim <- phenosplit[[i]]
    if (length(stim)==0){
      res[i,,] <- NA
    } else{
    w.y <- (stim>0)*1
    y <- stim[w.y==1]
    lrtmp <- lrtest(w.x, w.y, x, y)
    res[i-1,,1:3] <- lrtmp
    tt <- t.test(2^unstim-1, 2^stim-1, var.equal=TRUE)
    res[i-1,1,4] <- tt$stat
    res[i-1,2,4] <- sign(tt$stat)
    res[i-1,3,4] <- tt$p.value
  }
  }
    dn <- dimnames(lrtmp)
    dn$component <- c(dn$component, 'zeroes')
    dimnames(res) <- c(list(geneid=names(phenosplit)[-1]), dn)
    res
  })

  m <- melt(lrout)
  m <- rename(m, c('X1'=comparison, 'X2'='metric', 'X3'='test.type', 'X4'=probeid))
  if(returnall){
    return(m)
  }
  retme<-subset(m, test.type=='comb')
  return(cast(rename(retme,c(metric="variable"))))                  
                }