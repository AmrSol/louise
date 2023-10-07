:-module(vanilla, [refresh_tables/1
		  ,prove/6
		  ,bind_head_literal/3
		  ,check_constraints/1
		  ,free_member/2
		  ,constraints/1
                  ]).

/** <module> Vanilla inductive Prolog meta-interpreter.

*/

:-table(prove/6).


%!	refresh_tables(+Action) is det.
%
%	Table or untable prove/6.
%
%	The Vanilla meta-interpreter implemented in prove/6 is tabled to
%	avoid infinite left-recursions during learning. This can
%	significantly reudce the timing of execution of a learning query
%	with the same experiment data.
%
%	However, if an experiment file is changed after a learning
%	query completes, it's possible that some of the changes do not
%	cause the memoization tables to be updated. For example, this is
%	the case when changing the refers to background predicates and
%	metarules in the second arguments of background_knowledge/2 and
%	metarules/2.
%
%	To try and ensure that learning proceeds from the latest version
%	of the MIL problem defined in an experiment file, this predicate
%	should be called by any learning predicate to clean up the
%	tables before a learning attempt.
%
%	As an example of its use, this predicate is called by
%	top_program/5 in louise.pl, as a "setup" step before executing
%	the goals for the generalisation and specialisation steps of
%	TPC:
%	==
%	top_program(Pos,Neg,BK,MS,Ts):-
%	% Uses the Prolog engine and avoids using the dynamic db too much.
%		configuration:theorem_prover(resolution)
%		,configuration:clause_limit(K)
%		,K > 0
%		,S = (write_problem(user,[BK],Refs)
%		     ,refresh_tables(table)
%		     )
%
%		% ... TPC code calling prove/6
%
%		,C = (erase_program_clauses(Refs)
%		     ,refresh_tables(untable)
%		     )
%		,setup_call_cleanup(S,G,C)
%	==
%
%	Note taht there is some slowdown when this predicate is called
%	between learning queries with different clause_limit/1 settings.
%	This may be because adding and removing tabling with table/1 and
%	untable/1, as done in this predicate, leaves behind some
%	garbage. The SWI-Prolog documentationr states that table/1 and
%	untable/1 are meant to be used at the top-level and that
%	abolish_table_subgoals/1 should be used instead to cleanup
%	tables programmatically. However, that predicate seems to cause
%	even more slowdown than table/1 and untable/1, so we're going
%	with the latter.
%
refresh_tables(table):-
	table(prove/6).
refresh_tables(untable):-
	configuration:untable_meta_interpreter(false)
	,!.
refresh_tables(untable):-
	configuration:untable_meta_interpreter(true)
	,untable(prove/6).



%!	prove(?Literals,+Limit,+Metarules,+Sig,+Acc,-Metasubs) is
%!	nondet.
%
%	A vanilla MIL meta-interpreter for Top Program Construction.
%
%	Literals is a set of encapsulated literals (as a "tree" of
%	Prolog terms, in parentheses) currently being refuted.
%
%	Limit is the clause limit defined in the configuration option
%	clause_limit/1. Limit restricts the number of distinct clauses
%	in a refutation sequence. Notably this is _not_ the number of
%	clauses _in a learned hypothesis_.
%
%	Metarules is a list of expanded metarules to be used in the
%	proof by refutation of each Literals.
%
%	Sig is the learning signature, a list of predicate symbols (but
%	not arities!) of the target predicates for a learning attempt.
%	Only symbols in Sig will be allowed to be bound to the
%	second-order variables in head literals of metarules and so
%	only clauses of those predicates will be found in the learned
%	metasubstitutions.
%
%	Acc is the accumulator of metasubstitutions.
%
%	Metasubs is a list of metasubstitution atoms derived during the
%	proof. Metasubstitution atoms are of the form:
%
%	m(Id,Tgt,P1,...,Pn)
%
%	Where Id is the atomic identifier of a metarule in Metarules;
%	Tgt is the predicate symbol (but not arity) of one target
%	predicate, and each Pi is the symbol of a background predicate
%	(which can also be the target predicate, or an invented
%	predicate, as well as a predicate actually  defined in the BK).
%
%	When this predicate is first called, Literals should be a single
%	encapsulated literal, one example of one target predicate. As
%	the proof-by-refutation proceeds, that original goal of the
%	proof is replaced by goals derived by resolution.
%
%	When the proof completes, if it completes successfully,
%	Metasubs should be a list of metasubstitution atoms, each of
%	which can be applied to its corresponding metarule (found via
%	the metasubstitution atom's first, Id, argument) to produce a
%	first-order clause. In that sense, the clauses of Metasubs are
%	the set of clauses in one refutation sequence of the original
%	example Literal.
%
%	The number of metasubstitution atoms in Metasubs can be at most
%	equal to Limit.
%
%	Since Metasubstitutions is a list of atoms in a refutation
%	sequence, this meta-interpreter is capable of inducing, for each
%	single example, an entire proof-branch refuting that example. In
%	other words, this is is a multi-clause learning inductive
%	meta-interpreter, capable of learning entire programs from one
%	example.
%
%	What is the motivation for multi-clause learning? Traditional
%	ILP systems like Aleph or Progol learn a single "rule" from each
%	positive example (and then remove examples "covered" by the
%	rule). That works fine until an example is found that cannot be
%	covered by a single rule. This is often the case with recursive
%	programs and certainly the case with predicate invention. The
%	ability to learn multiple clauses that resolve with each other
%	to refute a goal-example allows Louise (and MIL systems in
%	general) to learn recursive programs and to perform predicate
%	invention without the restrictions of earlier systems.
prove(true,_K,_MS,_Ss,Subs,Subs):-
	!
        ,debug(prove_steps,'Reached proof leaf.',[])
	,debug(prove_metasubs,'Metasubs so-far: ~w',[Subs]).
prove((L,Ls),K,MS,Ss,Subs,Acc):-
	debug(prove_steps,'Splitting proof at literals ~w -- ~w',[L,Ls])
	,prove(L,K,MS,Ss,Subs,Subs_)
	,prove(Ls,K,MS,Ss,Subs_,Acc).
prove((L),K,MS,Ss,Subs,Acc):-
        L \= (_,_)
	,L \= true
        ,debug(prove_steps,'Proving literal: ~w.',[L])
	,clause(L,K,MS,Ss,Subs,Subs_,Ls)
	,debug(prove_metasubs,'New Metasubs: ~w',[Subs_])
        ,debug(prove_steps,'Proving body literals of clause: ~w',[L:-Ls])
        ,prove(Ls,K,MS,Ss,Subs_,Acc).
/* % Uncomment for richer debugging and logging.
prove(L,_MS,_Ss,Subs,_Acc):-
	L \= true
        ,debug(prove,'Failed to prove literals: ~w',[L])
	,debug(prove,'Metasubs so-far: ~w',[Subs])
	,fail.
*/


%!	clause(?Literal,+K,+MS,+Sig,+Subs,-Subs_New,-Body) is nondet.
%
%	MIL-specific clause/2 variant.
%
%	This predicate is similar to clause/2 except that if the body of
%	a clause with the given Literal as head can't be found in the
%	program database, the metasubstitution store Subs is searched
%	for a known metasubstitution whose encapsulated head literal
%	unifies with Literal. If that fails, a new metasubstitution is
%	contsructed and added to the store.
%
%	Literal is a partially or fully instantiated literal to be
%	proved.
%
%	K is an integer, the clause limit defined in the configuration
%	option clause_limit/1. This limits the number of new
%	metasubstitutions added to the metasubstitution store.
%
%	MS is the set of metarules for the current MIL Problem.
%
%	Sigs is the predicate signature, a list of _atoms_ (not yet
%	predicate identifiers).
%
%	Subs is a list of encapsulated metasubstitution atoms.
%
%	Subs_New is the list Subs with any new metasubstitution
%	constructed.
%
%	Body is the body literals of Literal found in the database, or a
%	metasubstitution already in Subs, or a new one constructed by
%	new_metasub/6.
%
clause(_L,_K,_MS,_Ss,Subs,_Acc,_Ls):-
	\+ check_constraints(Subs)
	,!
	,fail.
clause(L,_K,_MS,_Ss,Subs,Subs,true):-
	(   predicate_property(L,foreign)
	;   built_in_or_library_predicate(L)
	)
	,debug(fetch,'Proving built-in literal: ~w', [L])
        ,call(L)
	,debug(fetch,'Proved built-in clause: ~w', [L:-true]).
clause(L,_K,_MS,_Ss,Subs,Subs,Ls):-
	\+ predicate_property(L,foreign)
	,\+ built_in_or_library_predicate(L)
	,debug(fetch,'Proving literal with BK: ~w', [L])
        ,clause(L,Ls)
	,debug(fetch,'Trying BK clause: ~w', [L:-Ls]).
clause(L,_K,MS,_Ss,Subs,Subs,Ls):-
        debug(fetch,'Proving literal with known metasubs: ~w',[L])
        ,known_metasub(L,MS,Subs,Ls).
clause(L,K,MS,Ss,Subs,Subs_,Ls):-
	length(Subs,N)
	,N < K
        ,debug(fetch,'Proving literal with new metasub: ~w',[L])
        ,new_metasub(L,MS,Ss,Subs,Subs_,Ls).


%!	check_constraints(+Metasubs) is det.
%
%	True if all ground metasubstitutions obey constraints.
%
%	Metasubs is the list of metasubstitutions derived so-far. For
%	each _ground_ metasubstitution in Metasubs, this predicate
%	checks that it does not violate any constraints declared in a
%	metarule_constraints/2 clause.
%
check_constraints(Subs):-
	forall(member(Sub,Subs)
	      ,(   ground(Sub)
	       ->  constraints(Sub)
	       ;   \+ ground(Sub)
	       )
	      ).


%!	known_metasub(?Literal,+Subs,-Body) is nondet.
%
%	Selects a known metasubstition whose head unifies with Literal.
%
known_metasub(L,MS,Subs,Ls):-
	member(Sub,Subs)
        ,applied_metasub(MS,Sub,L,Ls)
	,debug(fetch,'Trying known metasub: ~w',[Sub]).


%!	applied_metasub(+Metarules,?Metasubstitution,?Head,-Body)
%!	is nondet.
%
%	Get the encapsulated body literals of a Metasubstitution.
%
applied_metasub(MS, Sub, H, B):-
        free_member(Sub:-(H,B),MS)
	,!.
applied_metasub(MS, Sub, L, true):-
	free_member(Sub:-(L),MS).


%!	free_member(?Element,?List) is nondet.
%
%	member/2 variant that copies elements without unifying them.
%
%	Used to avoid binding all instances of a metarule throughout a
%	proof branch.
%
free_member(Z,Xs):-
	free_member(_X,Xs,Z).

%!	free_member(?Element,?List,?Copy) is nondet.
%
%	Business end of free_member/2.
%
free_member(X,[Y|_],Z):-
	unifiable(X,Y,_)
	,copy_term(Y,Y_)
	% Unifying in copy_term/2 may fail.
	,Y_ = Z.
free_member(X,[_|Ys],Z):-
	free_member(X,Ys,Z).



%!	new_metasub(?Literal,+MS,+Sig,+Subs,-New_Subs,-Body) is nondet.
%
%	Constructs new metasubstitutions whose heads unify with Literal.
%
new_metasub(L,MS,Ss,Subs,[Sub|Subs],Ls):-
        member(M,MS)
        ,applied_metasub(Sub,M,Ss,L,Ls)
	,debug(fetch,'Added new metasub: ~w',[Sub]).


%!	applied(?Metasubstitution,+Metarule,+Sig,?Head,-Body) is
%!	nondet.
%
%	Construct a new Metasubstitution whose head unifies with Head.
%
applied_metasub(Sub, M, Ss, H, Ls):-
	copy_term(M,M_)
	,M_ = (Sub:-(H,Ls))
	,bind_head_literal(H,M_,(Sub:-(H,Ls)))
	,member(S,Ss)
        ,symbol(H,S).
applied_metasub(Sub, M, Ss, H, H):-
	copy_term(M,M_)
	,M_ = (Sub:-(H))
	,bind_head_literal(H,M_,(Sub:-(H)))
	,member(S,Ss)
        ,symbol(H,S).


%!	bind_head_literal(+Example,+Metarule,-Head) is det.
%
%	Bind an Example to the encapsulated Head literal of a Metarule.
%
%	Abstracts the complex patterns of binding examples to the heads
%	of metarules with and without body literals.
%
bind_head_literal(H:-B,(Sub:-(H,B)),(Sub:-(H,B))):-
% Positive or negative example given as a definite clause
% with one or more body literals.
	configuration:example_clauses(bind)
	,!.
bind_head_literal(H:-B,(Sub:-(H,Ls)),(Sub:-(H,Ls))):-
	configuration:example_clauses(call)
	,user:call(B)
	,!.
bind_head_literal(E,M,(H:-(E,Ls))):-
% Positive example given as a unit clause.
	M = (H:-(E,Ls))
	,!.
bind_head_literal(:-E,M,(H:-(E,Ls))):-
% Negative example given as a unit clause
	M = (H:-(E,Ls))
	,!.
bind_head_literal(E,M,(H:-(E,true))):-
% Positive example given as a unit clause.
% M is the Abduce metarule, i.e. body-less clause.
	M = (H:-E)
	,!.
bind_head_literal(:-E,M,(H:-(E,true))):-
% Negative example given as a unit clause.
% M is the Adbuce metarule, i.e. body-less clause.
	M = (H:-E)
	,!.
bind_head_literal(:-(L,Ls),M,(S:-(H,L,Ls))):-
% Negative example given as a Horn goal with no head literal.
% In this case, metasubstitution/3 must fail if the head of the
% metarule is entailed by its body literals.
% Note that binding the example to the body literals of the metarule
% will also bind the shared variables in the head of the metarule.
	M = (S:-(H,L,Ls))
	,!.


%!	symbol(?Literal,+Symbol) is det.
%
%	Instantiate a literal's predicate symbol to the given Symbol.
%
symbol(L,S):-
        L =.. [m,S|_As].



%!	constraints(+Metasubstitution) is det.
%
%	Apply a set of constraints to a generalising Metasubstitution.
%
%	Metasubstitution is a generalising metasubstitution considered
%	for addition to the Top program. A generalising metasubstitution
%	is one found during the generalisation step of Top program
%	construction.
%
%	constraints/1 tests Metasubstitution against a set of
%	user-defined constraints. If each applicable constraint is true,
%	then constraints/1 succeeds and Metasubstitution is included in
%	the Top program. Otherwise constraints/1 fails and
%	Metasubstitution is excluded from the Top program.
%
%	Note that only metasubstitutions found to generalise an example
%	are tested for constraints, i.e. metasubstitutions that can not
%	be proven against the MIL problem will be excluded without
%	constraints being tested.
%
%	User-defined constraints
%	------------------------
%
%	User-defined constraints are declared in experiment files as
%	clauses of configuration:metarule_constraints/2:
%
%	==
%	configuration:metarule_constraints(?Metasub,+Goal) is semidet.
%	==
%
%	A metarule_constraints/2 clause can be any Prolog clause. To
%	clarify, it can be a unit clause (a "fact"), or a non-unit
%	clause (a "rule").
%
%	The first argument of metarule_constraints/2 should match the
%	metasubstitution atom of an encapsulated metarule (the functor
%	must be "m" not "metarule"). If a generalising metasubstitution
%	matches this first argument, the matching metarule_constraint/2
%	clause is called. If this first call succeeds, the Prolog goal
%	in the second argument is called to perform the constraint test.
%
%	The second argument of metarule_constraints/2 is an arbitrary
%	Prolog goal. When the first argument of metarule_constraints/2
%	matches a generalising metasubstitution and the initial call
%	to metarule_constraint/2 succeds, the second argument is passed
%	to call/1. If this second call fails, the constraint test fails
%	and the metasubstitution matching the first argument is removed
%	from the generalised Top program. If this second calls succeeds,
%	the cosntraint test passes and the metasubstitution is added to
%	the generalised Top program.
%
%	Example
%	-------
%
%	The following metarule constraint will match a metasubstitution
%	with any metarule Id and with three existentially quantified
%	variables all ground to the same term. When the match succeeds,
%	and given that the constraint is a unit clause (i.e. always
%	true), the second argument of the constraint, fail/0 will be
%	called causing the constraint to fail and the metasubstitution
%	to be discarded:
%
%	==
%	configuration:metarule_constraints(m(_ID,P,P,P),fail).
%	==
%
%	The metarule constraint listed above can be used to exclude
%	left-recursive clauses from the Top program, but only for
%	metarules with exactly two body literals. A more general
%	constraint that will apply to a metarule with an arbitrary
%	number of body literals is as follows:
%
%	==
%	configuration:metarule_constraints(M,fail):-
%	M =.. [m,_Id,P|Ps]
%	,forall(member(P1,Ps)
%	       ,P1 == P).
%	==
%
%	Alternatively, the symbol of a target predicate can be specified
%	so that only metasubstitutions of that predicate are excluded
%	(if they would result in left-recursive clauses):
%
%	==
%	configuration:metarule_constraints(M,fail):-
%	M =.. [m,_Id,ancestor|Ps]
%	,forall(member(P1,Ps)
%	       ,P1 == ancestor).
%	==
%
%	Or the metarule Id can be ground to test only metasubstitutions
%	of a specific metarule, and so on.
%
%
%	Metarule constraints and predicate invention
%	--------------------------------------------
%
%	In the above examples, note the use of ==/2 instead of =/2 to
%	perform the comparison between existentially quantified
%	variables. This is to allow for variables remaining unbound on
%	generalisation during metarule extension by unfolding in the
%	proces of predicate invention.
%
%	@see data(examples/constraints) for examples of using metarule
%	constraints, in particular for the purpose of excluding
%	metasubstitutions resulting in left-recursive clauses from the
%	Top progam.
%
constraints(_Sub):-
	predicate_property(metarule_constraints(_,_), number_of_clauses(0))
	,!.
constraints(Sub):-
	predicate_property(metarule_constraints(_,_), number_of_clauses(N))
	,N > 0
	,copy_term(Sub,Sub_)
	,forall(configuration:metarule_constraints(Sub_, C)
	       ,user:call(C)
	       ).
