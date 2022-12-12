
open FArray

type game = Freecell | Seahaven | Midnight | Baker

type gameStruct = {
  name : game;
  registers : Card.card option FArray.t;
  columns : Card.card list FArray.t;
  depots : Card.card list FArray.t;
}

(* On ajoute i cards dans la liste l *)
let rec add l cards i = 
  if i > 0 then 
    match cards with
    | [] -> (l, cards)
    | a :: subCards -> add ((Card.of_num a) :: l) subCards (i-1)
  else
    (l, cards)

(* cardsPerCol est une liste contenant dans l'ordre le nombre de cartes à ajouté dans chaque colonne 
   On ajoute donc nbCards dans chaque colonne (sous forme de liste) de columns *)
let rec add_column columns cards cardsPerCol incr =
  match cardsPerCol with
  | [] -> (columns, cards)
  | nbCard :: subCardsPerCol -> 
    let (col, subCards) = add [] cards nbCard in
    let newCol = set columns incr col in
      add_column newCol subCards subCardsPerCol (incr + 1)

let initGameAux gameType nbReg cards cardsPerCol =
  let registers = FArray.make nbReg None in
  let columns = FArray.make (List.length cardsPerCol) [] in
  let depots = FArray.make 4 [] in
  let (columns, cards) = add_column columns cards cardsPerCol 0 in
  let registers = 
    match cards with
    | c1 :: c2 :: cards -> let reg1 = set registers 0 (Some (Card.of_num c1)) in
                           let reg2 = set reg1 1 (Some (Card.of_num c2)) in reg2
    | _ -> registers
  in {name = gameType ; columns = columns ; registers = registers; depots = depots}

let initGame gameType cards =
  match gameType with
  | Freecell -> initGameAux Freecell 4 cards [7;6;7;6;7;6]
  | Seahaven -> initGameAux Seahaven 4 cards (List.init 10 (fun x -> 5)) 
  | Midnight -> initGameAux Midnight 0 cards ((List.init 17 (fun x -> 3)) @ [1])
  | Baker -> initGameAux Baker 0 cards (List.init 13 (fun x -> 4))
  (* | _ -> raise Not_found *)


(* Ecriture des fonctions pour la partie I/2, Peut qu'il faudra les mettres ailleurs plus tard *)

exception Empty_Stack

let push stack elt =
  match stack with
  | stack -> elt :: stack

let pop = function
  | [] -> raise Empty_Stack
  | a :: stack -> (a, stack)

let peek = function
  | [] -> None
  | a :: stack -> Some a

let empty = function
  | [] -> true
  | _ -> false

(* Recuperer l'index de la colonne qui contient cette carte *)
let get_col columns card_num =
  let col_list = FArray.to_list columns in
  let rec get_col_aux cols index =
    match cols with
    | [] -> None
    | col :: _ when card_num = 0 && (empty col) -> Some index
    | col :: sub_cols -> match (peek col) with
                         | Some card when (Card.to_num card) = card_num -> Some index
                         | _ -> get_col_aux sub_cols (index+1)
  in get_col_aux col_list 0

let empty_col columns = 
  get_col columns 0

(* Renvoie l'index de la carte dans les registres *)
let get_reg registers card_num =
  let reg_list = FArray.to_list registers in
  let rec get_reg_aux regs index =
    match regs with
    | [] -> None
    | card :: _ when card_num = 0 && card = None -> Some index
    | card :: sub_regs -> match card with
                          | Some card when (Card.to_num card) = card_num-> Some index
                          | _ -> get_reg_aux sub_regs (index+1)
  in get_reg_aux reg_list 0

(* Recuperer l'index du premier registre vide *)
let empty_reg registers =
  get_reg registers 0

exception No_Register
exception No_Column
exception No_Index

let remove_in_col cols card =
  let index = get_col cols card in
  match index with
  | None -> raise No_Index
  | Some i -> let col = get cols i in
              match col with
              | [] -> raise Empty_Stack
              | _ :: sl -> set cols i sl

let remove_in_reg regs card =
  let index = get_reg regs card in
  match index with 
  | None -> raise No_Index
  | Some i -> set regs i None

let remove game card = 
  try let reg = remove_in_reg game.registers card in
    {name = game.name; registers = reg; columns = game.columns; depots = game.depots}
  with No_Index -> let col = remove_in_col game.columns card in
    {name = game.name; registers = game.registers; columns = col; depots = game.depots}

let add_to_reg registers card =
  let reg = empty_reg registers in 
  match reg with
  | None -> raise No_Register
  | Some index -> set registers index (Some (Card.of_num card))

(* Si card2 = 0, alors get_col renvoie l'index de la premiere colonne vide. *)
let add_to_col columns card card2 =
  let index = get_col columns card2 in
  match index with
  | None -> raise No_Column
  | Some i -> let col = get columns i in
              set columns i ((Card.of_num card) :: col)

(* Verifier si card_num2 vaut bien [1,51] AVANT *)
let move game card_num location =
  let card2 = int_of_string(location) in
  match location with 
  | "T" -> let reg = add_to_reg game.registers card_num 
           in {name = game.name; registers = reg; columns = game.columns; depots = game.depots}
                           
  | "V" -> let columns = add_to_col game.columns card_num 0
           in {name = game.name; registers = game.registers; columns = columns; depots = game.depots}
  
  | _ when card2 > 0 && card2 < 52 -> let columns = add_to_col game.columns card_num card2
           in {name = game.name; registers = game.registers; columns = columns; depots = game.depots}
    
  | _ -> raise Not_found

  (*
  
  - Fonction rules
  - Normalisation
  - Résoudre: ça lit un fichier -> liste de lignes -> pour chaque ligne split sur l'espace -> puis normalisation, rules, remove, move sur mot1 mot2
  *)

let rank card =
  fst card

let suit card =
  snd card

  (* J'ai mis raise Not_Found à chaque fois *)
let rules game card_num location =
  if (get_col game.columns card_num) = None && (get_reg game.registers card_num) = None then false
  else
    let card2_num = int_of_string(location) in
    match location with 
    | "T" -> (empty_reg game.registers) = None (* Si pas de registre empty_reg renvoit None*)
    | "V" ->
      begin
        match game.name with
        | Freecell -> (empty_col game.columns) = None
        | Seahaven -> let card1 = (Card.of_num card_num) in 
                      if not (rank card1 = 13) then false
                      else (empty_col game.columns) = None
        | _ -> false (* car colonne vide ne sont pas remplissables dans les autres modes *)
      end 
    | _ when card2_num > 0 && card2_num < 52 -> 
      if (get_col game.columns card2_num) = None then false (* Si l'emplacement n'existe pas, si il n'y a pas de colonne avec card2 au bout *)
      else
          let card2 = Card.of_num card2_num in
          let card1 = Card.of_num card_num in 
      if not (rank card2 = rank card1 + 1) then false (* Si card1 n'est pas immediatement inferieure *)
      else 
        let suit1 = Card.num_of_suit (suit card1) in
        let suit2 = Card.num_of_suit (suit card2) in
        begin
          match game.name with
          | Freecell -> (suit1 < 2 && suit2 < 2) || (suit1 > 1 && suit2 > 1) (* Si couleur alternée *)
          | Seahaven -> suit1 = suit2 (* Si même type*)
          | Midnight -> suit1 = suit2 (* Si même type*)
          | Baker -> true (* si on arrive ici c'est bon pas de condition sur les types dans ce mode *)
        end

    | _ -> false

let wanted_depot_cards depots = 
  let depots_list = FArray.to_list depots in
  let rec wanted_aux l1 l2 suit_num =
    match l1 with
    | [] -> l2
    | depot :: sl -> let card = match (peek depot) with
           | None -> Some (1, Card.suit_of_num suit_num)
           | Some card when rank card <= 13-> Some ((rank card + 1), suit card)
           | _ -> None
           in wanted_aux sl (card :: l2) (suit_num + 1)
    in let cards = wanted_aux depots_list [] 0
    in List.filter (fun e -> e != None) cards


let normalisation game =
  let wanted_cards = wanted_depot_cards game.depots in
  let rec normalisation_aux game cards =
    match cards with
    | [] -> game
    | card :: sub_cards -> try
                      let new_game = remove game card in
                      normalisation_aux new_game sub_cards
                    with _ -> normalisation_aux game sub_cards
    in normalisation_aux game wanted_cards


(* Il faut mettre les rois en haut dans Seahaven *)