import collections
import csv
import os
import subprocess
import sys
import tempfile

results = []

f = open("%s.out.csv" % sys.argv[1])
rdr = csv.DictReader(f)
for row in rdr:
    results.append({"benchmark": row["benchmark"],
                    "group":     row["group"],
                    "threads":   int(row["threads"]),
                    "time":      float(row["time"]),
                    "timeout":   row["timeout"] == "True"})
f.close()

timeouts = set(r["benchmark"] for r in results if r["timeout"])
print timeouts

groups = set(r["group"] for r in results)
norms = {grp: sum(r["time"] for r in results 
                                if r["threads"] == 1 
                                    and r["group"] == grp 
                                    and r["benchmark"] not in timeouts)
              for grp in groups}

groups = collections.defaultdict(lambda: collections.defaultdict(list))
for r in results:
    if r["benchmark"] not in timeouts:
        groups[r["group"]][r["threads"]].append(r["time"])
means = collections.defaultdict(dict)
for g in groups:
    for t in groups[g]:
        means[g][t] = norms[g] / sum(groups[g][t])

f = open("%s.csv" % sys.argv[1], "w")
f.write("\"group\",\"threads\",\"normtime\"\n")
for g in means:
    for t in means[g]:
        f.write("%s,%d,%f\n" % (g, t, means[g][t]))
f.close()

fR = tempfile.NamedTemporaryFile()
fR.write('''
library(ggplot2)
library(grid)
library(reshape2)
library(gridExtra)
library(scales)

df <- read.csv("%s")
df <- df[df$group!="hd-d0",]

df$group <- factor(df$group, c("arraysearch", "qm", "hd-d0", "hd-d5", "parrot"))
levels(df$group)[levels(df$group)=="hd-d5"] <- "Hacker's Delight d5"
levels(df$group)[levels(df$group)=="parrot"] <- "Parrot"
levels(df$group)[levels(df$group)=="arraysearch"] <- "Array Search"
levels(df$group)[levels(df$group)=="qm"] <- "CIA"

colors <- c("Hacker's Delight d5" = "#5173ab",
            "Array Search" = "#59C86A",
            "Parrot" = "#be5458",
            "CIA" = "#8375af")

p <- ggplot(df, aes(x=threads, y=normtime, colour=group, shape=group))

p <- p + geom_line(size=0.4) + geom_point()

p <- p + scale_x_continuous(trans=log_trans(2), breaks=c(1,2,4,8), limits=c(1,8))
p <- p + scale_colour_manual(values=colors)

p <- p + theme_bw(9)
p <- p + theme(plot.margin=unit(c(0.2, 0.2, 0, 0), "cm")) 

p <- p + labs(x="Threads", y="Speedup", colour="Benchmarks", shape="Benchmarks")

p <- p + theme(legend.position=c(0.19, 0.76),
               legend.background=element_blank(),
               legend.margin=unit(c(-1), "cm"),
               legend.key=element_blank(),
               legend.key.size=unit(c(0.35), "cm"))
p <- p + theme(panel.border=element_rect(fill=NA, size=0.4, colour="#aaaaaa"))

ggsave("./%s.pdf", p, width=3.5, height=2.16)
''' % (f.name, sys.argv[1]))
fR.flush()

subprocess.check_call(["Rscript", fR.name])

fR.close()
