:-module(recipes, [background_knowledge/2
		  ,metarules/2
		  ,positive_example/2
		  ,negative_example/2
		  ,replace/4
		  ,break_eggs/2
		  ,whisk_eggs_dem_dem/2
		  ,heat_oil/2
		  ,fry_eggs/2
		  ,season/2
		  ,replace/4
		  ,scramble/2
		  ]).

:-use_module(configuration).

% configuration:metarule_constraints(m(chain,P,P,_),fail).
% configuration:metarule_constraints(m(chain,P,_,P),fail).
% configuration:metarule_constraints(m(chain, _, _, recipe), fail).
% configuration:metarule_constraints(m(chain, _, recipe, _), fail).
% configuration:metarule_constraints(m(chain, _, Q, _), fail):-
% 	   memberchk(Q, ['$1', '$2']).
% configuration:metarule_constraints(m(chain, recipe, _, '$2'), fail).

% Can replace the last two constraints:
% configuration:metarule_constraints(m(chain, _, Q, _), fail):-
% 	   memberchk(Q, [recipe, '$1', '$2']).

% :- auxiliaries:set_configuration_option(clause_limit, [4]).
% :- auxiliaries:set_configuration_option(max_invented, [2]).
% :- auxiliaries:set_configuration_option(reduction, [plotkins]).
% :- auxiliaries:set_configuration_option(unfold_invented, [false]).

background_knowledge(recipe/2,[break_eggs/2
			      ,whisk_eggs_dem_dem/2
			      ,heat_oil/2
			      ,fry_eggs/2
			      ,season/2
			      ,replace/4
				  ,scramble/2
			      ]).

metarules(recipe/2,[chain]).

% Replace clause above with this one to obtain more specific recipes
% only working for making omelette
% metarules(recipe/2,[chain_abduce_y]).

positive_example(recipe/2,E):-
	member(E, [recipe([egg_whisk,eggs,frying_pan,frying_oil,pepper,salt],[omelette])
		  ]).

negative_example(recipe/2,_):-
	fail.

% This only works if egg is the first or second, or third?? element in the list. 
% Its kinda all over the place.
break_eggs(Xs,Ys):-
	replace([eggs],Xs,[egg_whites,egg_yolks],Ys).
whisk_eggs_dem_dem(Xs,Ys):-
	replace([egg_whisk,egg_whites,egg_yolks],Xs,[whisked_eggs],Ys).
% heat_oil(Xs,Ys):-
% 	replace([frying_pan,olive_oil],Xs,[frying_oil],Ys).
fry_eggs(Xs,Ys):-
	replace([frying_oil,whisked_eggs],Xs,[frying_eggs],Ys).
season(Xs,Ys):-
	replace([frying_eggs,pepper,salt],Xs,[omelette],Ys).
scramble(Xs,Ys):-
	replace([omelette],Xs,[scrambled_omelette],Ys).



replace(Xs,Is,Ys,Os):-
	ground(Xs)
	,ground(Is)
	,ground(Ys)
	,ord_subset(Xs,Is)
	,ord_subtract(Is,Xs,Zs_)
	,ord_union(Ys,Zs_,Os).


% % Target theory for an omelette recipe.
% recipe_(As,Fs):-
% 	break_eggs(As,Bs)
% 	,whisk_eggs_dem_dem(Bs,Cs)
% 	,heat_oil(Cs,Ds)
% 	,fry_eggs(Ds,Es)
% 	,season(Es,Fs).