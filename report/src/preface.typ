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
  [Title],table.cell(colspan: 3)[Ground Station Contact and Data Volume Report],
  [Issue],[1],[Revision Number],[0],
  [Author(s)],[Nicolò Basso],[Release Date],[18-10-2026],
  [Review by],[TBD],[Date of Review],[TBD],
  [Approved by],[TBD],[Date of approval],[TBD]
  )

]

#align(bottom)[
  
#heading(outlined: false, level: 2, numbering: none)[Distribution]

This document is meant to be distributed within the DVS team and with the ESA FYS Team.
]