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
                    "opts":      row["opts"],
                    "time":      float(row["time"]),
                    "timeout":   row["timeout"] == "True"})
f.close()

timeouts = set(r["benchmark"] for r in results if r["timeout"])
print timeouts

groups = set(r["group"] for r in results)
norms = {grp: sum(r["time"] for r in results 
                                if r["opts"] == "none" 
                                    and r["group"] == grp 
                                    and r["benchmark"] not in timeouts)
              for grp in groups}

groups = collections.defaultdict(lambda: collections.defaultdict(list))
for r in results:
    if r["benchmark"] not in timeouts:
        groups[r["group"]][r["opts"]].append(r["time"])
means = collections.defaultdict(dict)
for g in groups:
    for t in groups[g]:
        means[g][t] = norms[g] / sum(groups[g][t])

f = open("%s.csv" % sys.argv[1], "w")
f.write("\"group\",\"opts\",\"normtime\"\n")
for g in means:
    for o in means[g]:
        f.write("%s,%s,%f\n" % (g, o, means[g][o]))
f.close()

fR = tempfile.NamedTemporaryFile()
fR.write('''
library(ggplot2)
library(grid)
library(reshape2)
library(scales)

df <- read.csv("%s")
df <- df[df$group!="hd-d0",]

df$group <- factor(df$group, rev(c("arraysearch", "qm", "hd-d0", "hd-d5", "parrot")))
levels(df$group)[levels(df$group)=="hd-d5"] <- "Hacker's Delight d5"
levels(df$group)[levels(df$group)=="parrot"] <- "Parrot"
levels(df$group)[levels(df$group)=="arraysearch"] <- "Array Search"
levels(df$group)[levels(df$group)=="qm"] <- "CIA"

levels(df$opts)[levels(df$opts)=="both"] <- "Both"
levels(df$opts)[levels(df$opts)=="cex"] <- "CEXs"
levels(df$opts)[levels(df$opts)=="structure"] <- "Structure"
levels(df$opts)[levels(df$opts)=="none"] <- "None"
df$opts <- factor(df$opts, c("None", "Structure", "CEXs", "Both"))

colors <- c("Hacker's Delight d5" = "#5173ab",
            "Array Search" = "#59C86A",
            "Parrot" = "#be5458",
            "CIA" = "#8375af")

p <- ggplot(df, aes(x=opts, y=normtime, fill=group))

p <- p + geom_bar(stat='identity', position='dodge')

p <- p + scale_fill_manual(values=colors, guide=guide_legend(reverse=TRUE))

p <- p + theme_bw(9)
p <- p + theme(plot.margin=unit(c(0.2, 0.2, 0, 0), "cm")) 

p <- p + labs(x="Optimizations", y="Speedup", fill="Benchmarks")

p <- p + coord_flip()

p <- p + theme(legend.position=c(0.8, 0.25),
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
