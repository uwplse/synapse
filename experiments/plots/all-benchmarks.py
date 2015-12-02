import collections
import csv
import os
import re
import subprocess
import sys
import tempfile

def rename_benchmark(bm):
    if "hd-d0" in bm:
        return "%02d-d0" % int(re.match("\(.+ ([0-9]+)\)", bm).group(1))
    elif "hd-d5" in bm:
        return "%02d-d5" % int(re.match("\(.+ ([0-9]+)\)", bm).group(1))
    elif "array-search" in bm:
        return "arraysearch-%02d" % int(re.match("\(.+ ([0-9]+)\)", bm).group(1))
    elif "inversek2j-theta1" in bm:
        return "inversek2j-1"
    elif "inversek2j-theta2" in bm:
        return "inversek2j-2"
    elif "qm" in bm:
        return "%s" % re.match("\(qm (.+)\)", bm).group(1)
    else:
        return bm[1:-1]  # s-expr

f = open("%s.out.csv" % sys.argv[1])
rdr = csv.DictReader(f)
f2 = open("%s.csv" % sys.argv[1], "w")
f2.write("\"benchmark\",\"group\",\"time\",\"timeout\"\n")

for row in rdr:
    f2.write("%s,%s,%s,%s\n" % (rename_benchmark(row["benchmark"]), row["group"],
                             row["time"], row["timeout"]))

f2.close()
f.close()

fR = tempfile.NamedTemporaryFile()
fR.write('''
library(ggplot2)
library(grid)
library(reshape2)
library(gridExtra)
library(scales)

df <- read.csv("%s")
df$timeout_label = sapply(df$timeout, function(x) if (x=="True") return("*") else return(""))

df$group <- factor(df$group, c("arraysearch", "qm", "hd-d0", "hd-d5", "parrot"))
levels(df$group)[levels(df$group)=="hd-d0"] <- "Hacker's Delight d0"
levels(df$group)[levels(df$group)=="hd-d5"] <- "Hacker's Delight d5"
levels(df$group)[levels(df$group)=="parrot"] <- "Parrot"
levels(df$group)[levels(df$group)=="arraysearch"] <- "Array Search"
levels(df$group)[levels(df$group)=="qm"] <- "CIA"

clean_names <- gsub("arraysearch-0(.)", "arraysearch-\\\\1", df$benchmark)
labels <- setNames(clean_names, df$benchmark)
print(labels)

p <- ggplot(df, aes(x=benchmark, y=time))

p <- p + geom_bar(stat="identity", fill="#356384", width=0.85)
p <- p + facet_grid(. ~ group, scales="free_x", space="free_x")

p <- p + geom_text(aes(label=timeout_label, x=benchmark, y=time+1), size=3)
p <- p + theme_bw(9)
p <- p + theme(plot.margin=unit(c(0.2, 0.2, 0, 0), "cm")) 

p <- p + scale_y_log10(expand=c(0,0), breaks=c(10, 100, 1000, 10000), limits=c(1, 20000))
p <- p + scale_x_discrete(labels=labels)

p <- p + labs(x="Benchmark", y="Solving time (secs)")

p <- p + theme(legend.position="none")
p <- p + theme(axis.text.x=element_text(angle=90, vjust=0.5, hjust=1.0, size=5,margin=margin(0)))
p <- p + theme(strip.background=element_rect(fill="#eeeeee", size=0.4, colour="#aaaaaa"))
p <- p + theme(panel.border=element_rect(fill=NA, size=0.4, colour="#aaaaaa"))
p <- p + theme(axis.ticks.x=element_blank())

ggsave("./%s.pdf", p, width=7, height=2.16)
''' % (f2.name, sys.argv[1]))
fR.flush()

subprocess.check_call(["Rscript", fR.name])

fR.close()
