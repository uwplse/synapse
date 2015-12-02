import collections
import csv
import os
import re
import subprocess
import sys
import tempfile

f = open("%s.out.txt" % sys.argv[1])

# generate a list of events
SAT = 0
UNSAT = 1
START = 2
FINISH = 3
events = []
for line in f:
    m = re.search("\[t=([0-9\.]+)s\] SAT <.+> with cost ([0-9]+)", line)
    if m:
        time = float(m.group(1))
        cost = int(m.group(2))
        events.append((time, FINISH, SAT, cost))
        continue
    m = re.search("\[t=([0-9\.]+)s\] starting sketch .+ \[(.+) remaining; (\d+) complete; (\d+) samples\]", line)
    if m:
        time = float(m.group(1))
        remaining = m.group(2)
        if remaining != "+inf.0":
            remaining = int(remaining)
        complete = int(m.group(3))
        events.append((time, START, remaining, complete))
        continue
    m = re.search("\[t=([0-9\.]+)s\] (UNSAT|TIMEOUT)", line)
    if m:
        time = float(m.group(1))
        events.append((time, FINISH, UNSAT))
        continue
f.close()

# sort events by time
events = sorted(events, key=lambda e: e[0])

# write CSV
f = open("%s.csv" % sys.argv[1], "w")
f.write("\"time\",\"remaining\",\"complete\",\"cost\"\n")

remaining = ""
complete = 0
best_cost = ""
for evt in events:
    t = evt[0]
    if evt[1] == START:
        if evt[2] != "+inf.0":
            remaining = evt[2]
    elif evt[1] == FINISH:
        if evt[2] == SAT:
            if best_cost == "" or evt[3] < best_cost:
                best_cost = evt[3]
        elif evt[2] == UNSAT:
            complete += 1
            if remaining != "":
                remaining -= 1
        f.write("%f,%s,%s,%s\n" % (t, remaining, complete, best_cost))

f.close()

fR = tempfile.NamedTemporaryFile()
fR.write('''
library(ggplot2)
library(grid)
library(reshape2)
library(scales)

df <- read.csv("%s")
melted <- melt(df, id.vars=c("time"))

levels(melted$variable)[levels(melted$variable)=="remaining"] <- "Sketches remaining"
levels(melted$variable)[levels(melted$variable)=="complete"] <- "Sketches complete"
levels(melted$variable)[levels(melted$variable)=="cost"] <- "Best cost"

colors <- c("Sketches remaining" = "#5173ab",
            "Sketches complete" = "#be5458",
            "Best cost" = "#59C86A")
lines <- c("Sketches remaining" = 1,
           "Sketches complete" = 2,
           "Best cost" = 1)

p <- ggplot(melted, aes(x=time, y=value, colour=variable, linetype=variable))

p <- p + geom_line(size=0.4)

p <- p + scale_colour_manual(values=colors) + scale_linetype_manual(values=lines)

p <- p + theme_bw(9)
p <- p + theme(plot.margin=unit(c(0.2, 0.2, 0, 0), "cm")) 

p <- p + labs(x="Time (secs)", y="Sketches or Cost", colour="", linetype="")

p <- p + theme(legend.position=c(0.75,0.5), legend.margin=unit(c(-0.5), "cm"),
               legend.background=element_blank(), legend.key=element_blank(),
               legend.key.size=unit(c(0.35), "cm"))
p <- p + theme(panel.border=element_rect(fill=NA, size=0.4, colour="#aaaaaa"))

ggsave("./%s.pdf", p, width=3.5, height=2.16)
''' % (f.name, sys.argv[1]))
fR.flush()

subprocess.check_output(["Rscript", fR.name])

fR.close()
