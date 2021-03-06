% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/helper_routines.R
\name{defineMONITORvars}
\alias{defineMONITORvars}
\title{Helper routine to define the monitoring indicator and time since last visit}
\usage{
defineMONITORvars(data, ID, t, imp.I, MONITOR.name = "N",
  tsinceNis1 = "last.Nt")
}
\arguments{
\item{data}{Input \code{data.table} or \code{data.frame}}

\item{ID}{The name of the unique subject identifier (character, numeric or factor).}

\item{t}{The name of the time/period variable in \code{data}.}

\item{imp.I}{The name of the binary indicator of missingness or imputation for I at time point t. This is used for coding MONITOR(t-1):=1-imp.I(t).
When imp.I(t)=1 it means that the patient was not observed (no office visit) at time-point t and hence no biomarker was measured.}

\item{MONITOR.name}{The name of the new column that represents for each row t the indicator of being MONITORed (having a visit) at time points t+1.
This variable is added as a new column to the output dataset.
The column MONITOR(t) is set to 1 when the indicator imp.I (imputed biomarker) is 0 at time-point t+1 and vice versa.}

\item{tsinceNis1}{The name of the future column (created by this routine) that counts number of periods since last monitoring event at t-1. More precisely,
it is a function of the past \code{N(t-1)}, where 0 means that N(t-1)=1; 1 means that N(t-2)=1 and N(t-1)=0; etc.}

\item{I}{The name of the numeric biomarker value which determines the dynamic treatment rule at each time point t.}
}
\value{
A \code{data.table} in long format with ordering (I, CENS, TRT, MONITOR)
}
\description{
Helper routine to define the monitoring indicator and time since last visit
}
\section{Details}{


Convert the input long format data with the time ordering: (I(t), imp.I(t), C(t), A(t))
into the data format required by the stremr input functions: (I(t), C(t), A(t), N(t):=1-imp.I(t+1)).
N(t) at time-point t is defined as the indicator of being observed (having an office visit) at time point t+1 (next timepoint after t)
The very first value of I(t) (at the first time-cycle) is ALWAYS ASSUMED observed/measured (hence I.imp=0 for each first subject-time observation).
}

\section{Data Format}{


The input data.frame data needs to be in long format.

The format of the specified columns needs to be as follows.

The time ordering of the input data at each t is as follows: (I, imp.I, CENS, TRT)

The time ordering of the output data at each t is as follows: (I, CENS, TRT, MONITOR), where MONITOR(t)=1-imp.I(t+1).

In output data.table, MONITOR(t-1)=1 indicates that the biomarker I(t) at t is observed and vice versa.

In addition the output data.table will contain a column 'tsinceNis1', where:
\itemize{
  \item tsinceNis1(t) = 0 means that the person was monitored at time-point t-1.
  \item tsinceNis1(t) > 0 is the count of the number of cycles since last monitoring event.
}
}

