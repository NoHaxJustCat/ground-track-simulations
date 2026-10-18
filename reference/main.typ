/* Imports: */
// Note: these imports need to repeated for every file used in the document.

// Main import of the template
// This import contains the wrap-it and equate packages by default.
#import "src/lib.typ": *
#import "src/template.typ": *

// Extra packages to your liking
// Physics-reltated tools for equations
#import "@preview/physica:0.9.6": *
// Specifying quantities and units
#import "@preview/unify:0.7.1": num, numrange, qty, qtyrange
// Formatting of uncertainties
#import "@preview/zero:0.5.0"


// Main styling, containg the majority of typesetting including document layout, fonts, heading styling, figure styling, outline styling, etc. Some parts of the styling are customizable.
#show: base.with(
  // These first two parameters are only used for the pdf metadata.
  title: "Battery Lifetime Report",
  name: "DVS",
  // What is displayed at the top-right of the page. The top-left of the page displays the current chapter.
  rightheader: "",
  // Main and math fonts
  main-font: "Stix Two Text",
  math-font: "Stix Two Math",
  // Colors used for internal references (figures, equations, sections) and citations
  ref-color: olive,
  cite-color: blue,
  // Language, used for correct hyphenation patterns and default word for outline title, etc.
  language: "en",
  region: "GB",
)

#let issue = [1.0]
#let revision = [1.2]
#let authors = [Nicolò Basso]
#let date-revision = [28-04-2026]
#let subsidiary = [VSV 'Leonardo Da Vinci']
#let fys-supervisor = [Lily Ha, Cristina Del Castillo Sancho, Luca Bartolucci]
#let tud-supervisor = [Stefano Speretta, Sevket Uludag, Johan Vennekens]
#let place = [Faculty of Aerospace Engineering, Delft University of Technology]

/* Cover page */

#makecoverpage(
  // supply path to cover image
  img: image("src/img/cover-image.jpg"),
  // These arguments speak for themselves
  title: [Solar Power Generation],
  subtitle: [Da Vinci Satellite],
  issue: issue,
  revision: revision,
  authors: authors,
  date-revision: date-revision,
  // optional: change color to big box containing title, subtitle and name. Default is full black with 50% opacity.
  // main-titlebox-fill: color.hsv(0deg, 0%, 0%, 50%)
)

/* Title page */

#maketitlepage(
  // These first arguments are self-explanatory
  title: [Solar Power Generation],
  subtitle: [Systems Team],
  name: "Space Engineering Practical",
  defense-date: datetime.today().display("[weekday] [month repr:long] [day], [year]") + " at 10:00",
  // These following arguments appear in a small table below the main title, subtitle, author
  issue: issue,
  revision: revision,
  authors: authors,
  date-revision: date-revision,
  subsidiary: subsidiary,
  fys-supervisor: fys-supervisor,
  tud-supervisor: tud-supervisor,
  place: place,

  // The thesis committee should be an array of contents, consisting of all the committee members and their affiliations

  cover-description: [Render by Nicolò Basso, Blender.
  ],
  // Some more options of a publicity statement:
  // publicity-statement: [An electronic version of thesis is available at #link("https://repository.tudelft.nl", [`https://repository.tudelft.nl`]).],
  // publicity-statement: smallcaps[This thesis is confidential and cannot be made public.],
  publicity-statement: none,
  // The final set of arguments form the content of a table outlining all your supervisors. You can add as little or many as you want.
)

/* Remaining contents of front matter */


// Your preface here
// #lorem(250)




// Your Abstract here
// #lorem(250)



// After the front matter is complete, we switch page numbering from roman to arabic numbering, and restart counting. The next chapter created afterwards starts on page 1.

#pagebreak()
#include "src/preface.typ"

#outline()


#show: switch-page-numbering


#show math.equation.where(block: true): it => {
  v(2pt)
  it
  v(2pt)
}

#set math.equation(numbering: "1.")

#include "content.typ"


#bibliography(
  "references.bib",
  title: [References],
  style: "american-physics-society",
)

#show: appendix



