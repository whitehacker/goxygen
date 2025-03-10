#' extractDocumentation
#' 
#' Extracts doxygen-like GAMS documentation. Entries are introduced with an @type at the beginning
#' of the line. In case of @realization also GAMS code is read and interpreted, in all other cases
#' only the specific documentation comment is evaluated.  
#' 
#' @param path path to the file(s) which should be evaluated
#' @param start_type set type for first line of code. This can be useful
#' to extract documentation even if no documentation type has been set (e.g
#' reading equations.gms as type realization)
#' @param comment comment chars used for documentation comments
#' @return a list of documentation pieces with type as name of each element 
#' @author Jan Philipp Dietrich
#' @importFrom stringi stri_extract_all_regex stri_replace_all_regex
#' @seealso \code{\link{goxygen}}
#' @examples 
#' mainfile <- paste0(system.file("dummymodel",package="gms"),"/main.gms")
#' calcfile <- paste0(system.file("dummymodel",package="gms"),
#'                            "/modules/02_crazymodule/complex/calculations.gms")
#' # extracting information from the main file of the model                            
#' extractDocumentation(mainfile)
#' # extracting information from a file with some equations in it
#' extractDocumentation(calcfile)
#' 
#' @export

extractDocumentation <- function(path, start_type=NULL, comment="*'") {
  
  if(length(path)>1) {
    out <- list()
    for(p in path) {
      out <- append(out,extractDocumentation(p,start_type=start_type, comment=comment))
    }
    return(mergeDocumentation(out))
  }
  
  escapeRegex <- function(x) {
    return(gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", x))
  }
  
  removeComments <- function(x,comment) {
   return(grep(paste0("^(",escapeRegex(comment),"|[^*])"),x, value=TRUE)) 
  }
  
  extract_block <- function(x,comment) {
    code <- "@(\\w*) ?(.*)$"
    pattern <- paste0("^(",escapeRegex(comment),") *",code)
    type <- sub(pattern,"\\2",x[1])
    attrPattern <- "(\\w+)=\"([^\"]+)\""

     if (grepl(attrPattern, type)) {
        attrName <- sub(attPattern, "\\1", type)
        attrValue <- sub(attrPattern, "\\2", type)
        if (attrName == "extrapage") {
            contentStart <- grep(paste0("^", escapeRegex(comment), " @", type), x)
            contentEnd <- grep(paste0("^", escapeRegex(comment), " @stop"), x)
            if (length(contentEnd) > 0 && contentEnd[1] > contentStart) {
                contentExtracted <- x[(contentStart + 1):(contentEnd - 1)]
                x <- c(paste0(comment, attrValue), contentExtracted)
            }
        }
    }
    if(type=="equations") {
      x[1] <- sub(pattern,"\\1 \\3",x[1])
      x <- paste(x,collapse="\n")
      equation <- "(^|\n)[^\n]*?[ \n\t]*\\.\\.([^.]|\n)(.|\n)*?;"
      eq <- stri_extract_all_regex(x,equation)[[1]]
      if(length(eq)==1 && is.na(eq)) {
        eq <- NULL
      } else {
        eq <- gamsequation2tex(eq)
      }
      x <- stri_replace_all_regex(x,equation,paste(comment,"\n",comment,"#::.equation.::#","\n",comment,"\n"))
      x <- stri_extract_all_regex(x,paste0(escapeRegex(comment),".*(\\n|$)"))[[1]]
      x <- gsub(paste0("(\n|",escapeRegex(comment)," *)"),"",x)
      
      # fill in equations
      for(i in names(eq)) {
        delim <- ifelse(grepl("CONVERSION FAILED!",i,fixed = TRUE), "```","")
        x[grep("#::.equation.::#",x)[1]] <- paste0(delim,"\n",eq[i],"\n",delim)
      }
      type <- "description"
    } else if(type=="code") {
      com <- grepl(paste0("^",escapeRegex(comment)," *"),x)
      x[!com] <- paste0("```\n",x[!com],"\n```")
      x[com] <- sub(paste0("^",escapeRegex(comment)," *"),"",x[com])
      x[1] <- sub(code,"\\2",x[1])
      x <- paste(x,collapse="\n")
      x <- gsub("\n```\n```\n","\n",x,fixed=TRUE)
      x <- strsplit(x,"\n")[[1]]
      type <- "description"
    } else if(type=="stop") {
      return(NULL)
    } else {
      x <- grep(paste0("^",escapeRegex(comment)," *"), x, value=TRUE)
      x <- sub(paste0("^",escapeRegex(comment)," *"),"",x)
      x[1] <- sub(code,"\\2",x[1])
    }
    
    while(length(x)>1 & x[1]=="")  x <- x[-1]
    while(length(x)>1 & tail(x,1)=="") x <- x[-length(x)]
    if(length(x)==1) if(is.na(x) | x=="") return(NULL)
    if(type=="description") x <- c(x,"")
    out <- list()
    out[[type]] <- x
    return(out)
  }
  
  if(!file.exists(path)) return(list())
  x <- readLines(path, warn = FALSE)
  x <- removeComments(x,comment)
  if(!is.null(start_type)) {
    x <- c(paste0(comment," @",start_type," "),x)
  }
  
  blocks_start <- suppressWarnings(grep(paste0("^",escapeRegex(comment)," @[a-z]*( |$)"),x))
  if(length(blocks_start)==0) return(list())
  
  blocks_end <- c(blocks_start[-1]-1,length(x))
  
  blocks <- list()
  for(i in 1:length(blocks_start)) {
    blocks <- c(blocks,extract_block(x[blocks_start[i]:blocks_end[i]], comment))
  }
  return(mergeDocumentation(blocks))
}