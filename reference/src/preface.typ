#heading(outlined: false, level: 2, numbering: none)[Review and Approval]
#block[

#show table.cell.where(x: 0).or(table.cell.where(x: 2)): it => {
  set text(weight: "bold")
  it
}

#table(
  columns: (4cm,1fr, 4cm,1fr),
  stroke: 0.5pt,
  inset: 8pt,
  [Title],table.cell(colspan: 3)[Solar Power Generation Report],
  [Issue],[1],[Revision Number],[1],
  [Author(s)],[Nicolò Basso],[Release Date],[26-04-2026],
  [Review by],[Stefano Speretta],[Date of Review],[27-04-2026],
  [Approved by],[TBD],[Date of approval],[TBD]
  )

]

#v(3em)
  
#heading(outlined: false, level: 2, numbering: none)[Change Log]

#block[
#show table.cell.where(y: 0): it => {
  set text(weight: "bold")
  it
}

#table(
  columns: (4cm, 3cm,1fr,1fr, 1fr),
  stroke: 0.5pt,
  inset: 8pt,
  align: (x, y) => {if y == 0 or x!= 0 {center} else {auto}},
  [Reason for Change],[Author(s)],[Issue],[Revision],[Date],
  [Add validation],[Nicolò Basso],[1],[1],[26-04-2026],
  [Implement Professor Feedback],[Nicolò Basso],[1],[2],[28-04-2026],
  )]

#v(3em)
  
#heading(outlined: false, level: 2, numbering: none)[Change Record]

#block[
#show table.cell.where(y: 0): it => {
  set text(weight: "bold")
  it
}

#table(
  columns: (7cm, 3cm,1fr,1fr),
  stroke: 0.5pt,
  inset: 8pt,
  align: (x, y) => {if y == 0 or x!= 0 {center} else {auto}},
  [Reason for Change],[Author(s)],[Date],[Section(s)],
  [Added validation of the code],[Nicolò Basso],[26-04-2026],[3.2],
  [Specified the changes in power due to degradation],[Nicolò Basso],[28-04-2026],[2.2],
  [Removed other averages for clarity],[Nicolò Basso],[28-04-2026],[3.1],
  [Added lower bounds of expected power for reference purposes],[Nicolò Basso],[28-04-2026],[3.1],
  )]

#v(3em)

#align(bottom)[
  
#heading(outlined: false, level: 2, numbering: none)[Distribution]

This document is meant to be distributed within the DVS team and with the ESA FYS Team.
]