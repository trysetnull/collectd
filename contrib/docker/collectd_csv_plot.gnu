#!/usr/bin/gnuplot

set print "-"

if (!exists("collectd_ps_base_dir")) {
    print "Usage: gnuplot -e \"collectd_ps_base_dir='<collectd/csv/path>/processes-*'\" [-e \"VERBOSE='1'\"] ".ARG0
    exit 1
}

log_fmt(severity, message) = "[".system("date --rfc-3339='seconds'")."] [".severity."] ".message
getColumnHeader(file, column) = system("awk -F'[,]' '{ print $".column."; exit }' ".file)
numberOfColumns(file) = system("awk -F'[,]' '{ print NF; exit }' ".file)
getLineStyle(n, column, max_columns) = n * max_columns - max_columns - n + column
getKeyLabel(file, column) = system("basename $(dirname \"".file."\")")." [".getColumnHeader(file, column)."]"
getSubplotTitle(file) = system("echo -n ".file." | sed -rn 's,^.*/(.*)-([0-9]{4}-[0-9]+-[0-9]+)$,\\1 [\\2],p' | sed 's/_/ /g'")

if (exists("VERBOSE")) print log_fmt("INFO", "verbose logging active")

# ggplot2 color-blind-friendly palette with black.
set style line 1 lc rgb '#000000' lt 1 lw 2
set style line 2 lc rgb '#E69F00' lt 1 lw 2
set style line 3 lc rgb '#56B4E9' lt 1 lw 2
set style line 4 lc rgb '#009E73' lt 1 lw 2
set style line 5 lc rgb '#F0E442' lt 1 lw 2
set style line 6 lc rgb '#0072B2' lt 1 lw 2
set style line 7 lc rgb '#D55E00' lt 1 lw 2
set style line 8 lc rgb '#CC79A7' lt 1 lw 2

# Parse the dates
dates_str_cmd = "find ".collectd_ps_base_dir." -type f | \
    sed -rn 's/^.*([0-9]{4}-[0-9]+-[0-9]+)$/\\1/p' | \
    sort -u"
DATES_STR = system(dates_str_cmd)
if (exists("VERBOSE")) {
    print log_fmt("INFO", "DATES_STR system call: ".dates_str_cmd)
    print log_fmt("INFO", "DATES_STR: ".DATES_STR)
}

# Parse the metrics
metrics_str_cmd = "find ".collectd_ps_base_dir." -type f | \
    sed -rn 's,^.*/(.*)-[0-9]{4}-[0-9]+-[0-9]+$,\\1,p' | \
    sort -u"
METRICS_STR = system(metrics_str_cmd)
if (exists("VERBOSE")) {
    print log_fmt("INFO", "METRICS_STR system call: ".metrics_str_cmd)
    print log_fmt("INFO", "METRICS_STR: ".METRICS_STR)
}

# Parse the processes
TITLE_OF_PLOT = "collectd process metrics\n"

set datafile separator ","

# for each metric calculate the y-axis min/max over all dates and recorded processes
max(val1, val2) = (val1 > val2 ? val1 : val2)
min(val1, val2) = (val1 < val2 ? val1 : val2)
array Y_AXIS_MIN_MAX[2*words(METRICS_STR)]
SET_Y_AXIS_RANGE = "if (Y_AXIS_MIN_MAX[2*row -1] != Y_AXIS_MIN_MAX[2*row]) { set yrange[Y_AXIS_MIN_MAX[2*row -1]*0.97:Y_AXIS_MIN_MAX[2*row]*1.03] }"
do for [row=1:words(METRICS_STR)] {
    max_idx = row*2
    min_idx = max_idx -1
    if (exists("VERBOSE")) { print log_fmt("INFO", "index tuple: (".min_idx.":".max_idx.")") }
    do for [col=1:words(DATES_STR)] {
        SUBPLOT_METRICS = system("find ".collectd_ps_base_dir." -type f -path \"*/".word(METRICS_STR,row)."-".word(DATES_STR,col)."\"")
        MAX_COL_NUM=numberOfColumns(word(SUBPLOT_METRICS,1))
        do for [n=1:words(SUBPLOT_METRICS)] {
            if (exists("VERBOSE")) { print log_fmt("INFO", "subplot_metric: ".word(SUBPLOT_METRICS,n)) }
            do for [i=2:MAX_COL_NUM] {
                stats word(SUBPLOT_METRICS,n) using i nooutput
                if (col == 1 && n == 1 && i == 2) {
                    Y_AXIS_MIN_MAX[min_idx] = STATS_min
                    Y_AXIS_MIN_MAX[max_idx] = STATS_max
                }
                else {
                    Y_AXIS_MIN_MAX[min_idx] = min(STATS_min, Y_AXIS_MIN_MAX[min_idx])
                    Y_AXIS_MIN_MAX[max_idx] = max(STATS_max, Y_AXIS_MIN_MAX[max_idx])
                }
            }
        }
    }
}

if (exists("VERBOSE")) {
    to_string = ""
    length = |Y_AXIS_MIN_MAX|
    do for [i=1:length] {
        if (i % 2 == 1) {
            prefix = "("
            suffix = ""
        } else {
            prefix = ""
            suffix = ")"
        }
        to_string = to_string.prefix.sprintf("%f", Y_AXIS_MIN_MAX[i]).suffix.((i != length) ? ", " : "")
    }
    print log_fmt("INFO", "Y_AXIS_MIN_MAX: [".to_string."]")
}

# A single graph
# Each date is a subplot (column)
# Each metric is a subplot (row)
# all measured processes for a given date and metric are plotted in a single subplot
get_plot_width(num_of_columns) = max(1920, num_of_columns*384)
get_plot_height(num_of_rows) = num_of_rows*650
set terminal svg size get_plot_width(words(DATES_STR)),get_plot_height(words(METRICS_STR)) fname 'Verdana, Helvetica, Arial, sans-serif'
set output 'collectd_report.svg'

set grid
set xdata time
set timefmt "%s"
set format x "%H:%M:%S"
set xlabel 'time'
set xtics nomirror rotate by 90 right
set ytics nomirror

X_TICS_ON = "set xtics scale 1 format '%H:%M:%S'; \
    set xlabel 'time'"
X_TICS_OFF = "set xtics scale 0 format ''; \
    unset xlabel"

Y_TICS_ON = "set ytics scale 1 format"
Y_TICS_OFF = "set ytics scale 0 format ''"

# Divide up the screen left to right in n parts.
LEFT_SHIFT=0.05
RELATIVE_PLOT_WIDTH=(0.997-LEFT_SHIFT)/words(DATES_STR)

set multiplot layout words(METRICS_STR),words(DATES_STR) \
    title "{/:Bold=22 ".TITLE_OF_PLOT
    do for [row=1:words(METRICS_STR)] {
        @SET_Y_AXIS_RANGE
        do for [col=1:words(DATES_STR)] {

            set lmargin at screen (int(col)-1) * RELATIVE_PLOT_WIDTH + LEFT_SHIFT
            set rmargin at screen (int(col))   * RELATIVE_PLOT_WIDTH + LEFT_SHIFT

            if (row == words(METRICS_STR)) { @X_TICS_ON } else { @X_TICS_OFF }
            if (col == 1) { @Y_TICS_ON } else { @Y_TICS_OFF }

            SUBPLOT_METRICS = system("find ".collectd_ps_base_dir." -type f -path \"*/".word(METRICS_STR,row)."-".word(DATES_STR,col)."\"")
            MAX_COL_NUM=numberOfColumns(word(SUBPLOT_METRICS,1))
            set title getSubplotTitle(word(SUBPLOT_METRICS,1))

            plot for [n=1:words(SUBPLOT_METRICS)] for [column=2:MAX_COL_NUM] \
            FILE = word(SUBPLOT_METRICS,n) \
            FILE using 1:column with lines ls getLineStyle(n, column, MAX_COL_NUM) title getKeyLabel(FILE, column)
        }
        unset yrange
    }
unset multiplot
reset
