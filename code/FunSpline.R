##=============================================================================
#' Interpolate single value using splines
#' 
#' Inputing a set of x and y values (equal lenght) and a single x value 
#' to interpolate the y value of, this function uses the splinefun function
#' from the stats package as it's workhorse
#' 
#' @param x -- vector of x values
#' @param y -- vecotr of y values, has to be same lenght as x
#' @param threshold -- x threshold for which y needs to be interpolated
#'
#' @return -- retuns interpolated y value 
#' @export
#'
#' @examples
#' x <- c(1:5)
#' y <- sample(2:6, 5)
#' FunSpline(x,y,2.5)
#' x <- c(1:5)
#' y <- sample(2:6, 5)
#' FunSpline(x,y,2.5, method = "natural",  ties = mean)
#' plot(x, y, pch = 19)
#' lines(spline(x,y, n = 100, method="natural",  ties = mean))
#' abline(v = 2.5, col = "red")
#' abline(h = FunSpline(x,y,2.5, method = "natural",  ties = mean), col = "red", lty = 3)
#' 
#' 
#' 
FunSpline <- function(x, y, threshold = 15, method="monoH.FC",  ties = mean) {
  func = splinefun(x, y, method=method,  ties = ties)
  func(threshold)
}

