#lang scribble/base

@(require "../../scribble-api.rkt")
@(append-gen-docs
  `(module "type-check" (path "src/arr/compiler/type-check.arr")))

@docmodule["modules" #:noimport #t #:friendly-title "Modules"]{

We often want to write programs in separate pieces and store the pieces
independently. This can be for a number of reasons, a few are:

@itemlist[

@item{To provide library code to students (unseen to them).}

@item{To logically separate responsibilities of a program into different files
to make it easier for programmers to understand the code's layout.}

@item{To provide a boundary over which it's relatively simple to substitute one
implementation of a library for another.}

@item{To provide a boundary where the two sides may be implemented in different
languages, but can still share values.}

@item{To provide only a subset of defined names to a different part of a
program.}

@item{To manage names when the same (good) names may be in use in different
parts of the same program.}

@item{To support incremental compilation.}

]

Not all of these require a module system, but a module system can help with all
of them, and these use cases motivate Pyret's.

This section describes the components of Pyret's module system and how to use
it.

@section[#:tag "s:modules:quick-start"]{Quick Start}

The shortest way to get started using the module system is to understand three
key ideas:

@itemlist[
@item{How to provide names from a module}
@item{How to tell Pyret to locate a module from a different module}
@item{How to include names from a located module}
]

Here's a simple example that demonstrates all three.

In a file called @tt{list-helpers.arr}:

@pyret-block{
provide *

concat :: <A> List<A>, List<A> -> List<A>
fun concat(l1, l2):
  l.append(l1, l2)
end
}

In a file in the same directory called @tt{list-user.arr}:

@pyret-block{
include file("list-helpers.arr")

check:
  concat([list: 1, 2], [list: 3, 4]) is [list: 1, 2, 3, 4]
end
}

The @pyret{provide *} declaration tells Pyret to make @emph{all} the names
defined in the @tt{list-helpers.arr} module available to any module that
imports it. The @pyret{include file("list-helper.arr")} declaration tells Pyret
to find the module at the path given in quotes, and then make all the names it
provides available in the top-level of the module the @pyret{include} appears
in.

In general, @pyret{include} and @pyret{provide *} are handy ways to provide a
collection of definitions to another context across modules.

@section[#:tag "s:modules:finding-modules"]{Finding Modules}

The syntax for @pyret{import} and @pyret{include} statements specifies a
@emph{dependency}, which tells Pyret how to find the module. Here are some
examples of dependencies:

@pyret-block{
string-dict
file("path/to/a/file.arr")
js-file("path/to/a/file.arr.js")
my-gdrive("stored-in-gdrive.arr")
shared-gdrive("stored-in-gdrive-publicly.arr", "ABCDEFhijkl1234")
}

In general, a dependency is either:

@itemlist[
@item{Written as an identifier (like @pyret{string-dict} above), in which case
it refers to a built-in module.}
@item{Written as an identifier followed by string literals in parentheses, in
which case it is referring to a user-written module that is located and loaded
by the compiler.}
]

The compiler can be configured to load different types of locator; for example,
the @pyret{gdrive} locators only work in code.pyret.org, where it is assumed
the user is authenticated to Google Drive.

The meaning of the supported forms are:

@form["<id-import>" "<id-of-builtin>"]{
Imports the given builtin module. Many built-in modules are documented in this
documentation.
}

@form["file" "file(<path>)"]{
Find the module at the given @pyret{path}. If @pyret{path} is relative, it is
interpreted relative to the module the import statement appears in.
}

@form["js-file" "js-file(<path>)"]{
Like @pyret{file}, but expects the contents of the file to contain a
definition in @seclink["s:single-module" "JavaScript module format"]
}

@form["gdrive-js" "gdrive-js(<name>)"]{
Looks for a Pyret file with the given filename in the user's
@tt{code.pyret.org/} directory in the root of Google Drive.
}

@form["shared-gdrive" "shared-gdrive(<name>, <id>)"]{
Looks for a Pyret file with the given id in Google Drive. The file must have
the sharing settings set to “Public on the Web”. The name must match the actual
name of the underlying file. These dependencies can be most easily generated by
using the “Publish” menu from @tt{code.pyret.org}
}

@section[#:tag "s:modules:detailed-control"]{Detailed Control of Names}

In larger programs, or in more sophisticated libraries for students, it is
often useful to have quite precise control over which names are provided and
included across module boundaries. A programmer may want to provide only a
subset of the names defined in a module to maintain an abstraction, or to avoid
cluttering namespaces with definitions intended only for use internal to a
module.

To this end, Pyret supports several forms for controlling names of various
kinds. We show first a simple solution for name control that is syntactically
heavyweight on the importing side, then show broader techniques for name
control.

@subsection[#:tag "s:modules:import"]{@pyret{import} and Module Identifiers}

In @secref["s:modules:quick-start"] we showed @pyret{provide *} and
@pyret{include <dependency>} as a quick way to get names from one module to
another. This is convenient and often a good choice. However, there are
situations where this is inadequate. For example, what if we wish to use
functions from two different list-helper libraries, but some of the names
overlap?

Consider:

@pyret-block{
# list-helpers.arr
provide *
fun concat(l1, l2): l1.append(l2) end
fun every-other(l): ... end
}

@pyret-block{
# list-helpers2.arr
provide *
concat :: <A> List<List<A>> -> List<A>
fun concat(list-of-lists):
  for fold(acc from empty, l from list-of-lists): acc.append(l) end
end
fun is-odd-length(l): ... end
}

@pyret-block{
# in a separate file
include file("list-helpers.arr")
include file("list-helpers2.arr")

concat(???)
}

In this example, the name @pyret{concat} could have one of two
meanings. Since this is ambiguous, this program results in an error that
reports the conflict between names.

Neither of the list-helpers modules is @emph{wrong}, the module that uses both
simply needs more control in order to use the right behavior from each. One way
to get this control is to use @pyret{import}, rather than @pyret{include},
which allows the programmer to give a name to the imported module. This name
can then be used with @pyret{.} to refer to the names within the imported
module.


@pyret-block{
include file("list-helpers.arr") as LH1
include file("list-helpers2.arr") as LH2

check:
  LH1.concat([list: 1, 2], [list: 3, 4]) is [list: 1, 2, 3, 4]
  LH2.concat([list: [list: 1, 2], [list: 3]]) is [list: 1, 2, 3]
end
}

Using `import` to define a module identifier is a simple way to unambiguously
refer to individual modules' exported names, and avoids conflicting names. It
is always a straightforward way to resolve these ambiguities.

Some potential downsides of always using module ids are the verbosity of
prefixing all uses with @pyret{LH1}., and, in teaching settings, the need to
introduce the syntactic form @pyret{a.b} before it's strictly necessary, causing a
needless curricular dependency.

For situations where these issues become too onerous, Pyret provides more ways
to control names.

@subsection[#:tag "s:provide-fewer"]{Providing Fewer (and More) Names}

It is not required that a module provide @emph{all} of its defined names. To
provide fewer names than @pyret{provide *}, a module can use one or more
@emph{provide blocks}. The overall set of features allowed is quite broad, and
simple examples follow:

@bnf['Pyret]{
IMPORT: "provide"
COLON: ":"
STAR: "*"
AS: "as"
PARENSPACE: "("
RPAREN: ")"
COMMA: ","
TYPE: "type"
DATA: "data"
MODULE: "module"
DOT: "."
HIDING: "hiding"
END: "end"
PROVIDECOLON: "provide:"
PROVIDE: "provide"
FROM: "from"
provide-block: PROVIDECOLON [provide-spec (COMMA provide-spec)* [COMMA]] END

provide-spec: provide-name-spec

name-spec: STAR [hiding-spec] | module-ref | module-ref AS NAME
data-name-spec: STAR | module-ref

provide-name-spec: name-spec

hiding-spec: HIDING PARENSPACE [(NAME COMMA)* NAME] RPAREN

module-ref: (NAME DOT)* NAME
}

First, some simple examples. A module might define several names of values, and
only provide a few:

@pyret-block{
# A module that includes this one will only see concat and is-odd-length, and
# won't see concat-helper because it is not provided
provide:
  concat,
  is-odd-length
end

fun concat-helper(element, lst): ... end
fun concat(list1, list2): ... end
fun is-odd-length(l): ... end
}

A module might provide all of its values and exclude a few:

@pyret-block{
# This module provides the same exports as the one above
provide:
  * hiding (concat-helper)
end

fun concat-helper(element, lst): ... end
fun concat(list1, list2): ... end
fun is-odd-length(l): ... end
}

A module might rename some of the values it exports:

@pyret-block{
# This module provides two names: is-odd-length and append
provide:
  * hiding (concat-helper, concat),
  concat as append
end

fun concat-helper(element, lst): ... end
fun concat(list1, list2): ... end
fun is-odd-length(l): ... end
}

A module can also re-export values that it imported, and it can do so using
module ids:

@bnf['Pyret]{
PROVIDE: "provide"
FROM: "from"
END: "end"
COLON: ":"
COMMA: ","
provide-block: PROVIDE FROM module-ref COLON [provide-spec (COMMA provide-spec)* [COMMA]] END
}

For example, this module exports both one name it defines, and all the names
from @pyret{string-dict}:

@pyret-block{
provide from SD: * end
provide: my-string-dict-helper end
import string-dict as SD
fun my-string-dict-helper(): ... end
}

Note that since provides always come before imports, the @pyret{SD} used on
line 1 of the example above is defined two lines later.

Combining provides from multiple modules can be an effective way to put
together a library for students. For example, an introductory course in data
science may benefit from a helper library that gives access to the image,
chart, and table libraries:

@pyret-block{
provide from T: * end
provide from C: * end
provide from I: * end
import tables as T
import chart as C
import image as I
}

A student library that @pyret{include}s this module would have access to all of
the names from these three modules.


@subsection[#:tag "s:include-fewer"]{Including Fewer (and More) Names}

There are forms for @pyret{include} with the same structure as @pyret{provide}
for including particular names from other modules. All @pyret{include} forms
take a module id and a list of specifications of names to include.

Some examples:

@pyret-block{
# This program puts just two names from the builtin string-dict module into
# scope.
import string-dict as SD
include from SD:
  mutable-string-dict,
  make-mutable-string-dict
end
}

@pyret-block{
# This program imports and renames two values from the string-dict module
import string-dict as SD
include from SD:
  mutable-string-dict as dict,
  make-mutable-string-dict as make-dict
end
}

@pyret-block{
# This program includes all the value names from the string-dict module
import string-dict as SD
include from SD: * end
}

It is an error to include the same name with different meanings. For example,
we could not include the @pyret{map} function from the @pyret{lists} library
@emph{and} import the @pyret{string-dict} constructor as @pyret{map}:

@pyret-block[#:style "bad-ex"]{
import lists as L
import string-dict as SD
include from L: map end
include from SD: mutable-string-dict as map end
}

However, it is @emph{not} an error to include the same name multiple times if
it has the same meaning:

@pyret-block[#:style "good-ex"]{
# in "student-helpers.arr"
provide from L: map, filter, fold end
import lists as L

# in "student-code.arr"
include path("student-helpers.arr")
import lists as L
include from L: map end
# map included again here, but it's OK because the other map is the same
}


@subsection[#:tag "s:modules:name-kinds"]{The Kinds of Names}

The documentation above applies to names of values. In Pyret, we can define
names that refer to values, types, or modules.

Names for values are defined in many ways; by @pyret{fun} declarations, by
@pyret{data} declarations creating constructors, by simple variable
declarations like @pyret{x = 10}, and more.

Names for types are defined by @pyret{type} (which creates type aliases), and
@pyret{data} (which creates new types).

Names for modules are defined by @pyret{import} statements, discussed above.





}