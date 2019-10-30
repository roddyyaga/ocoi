module type A_sig = sig
  type t

  val f : t -> t
end

module A : A_sig with type t = string = struct
  type t = string

  let f s = s ^ "!"
end

module type B_sig = sig
  module My_a : A_sig

  val g : My_a.t -> My_a.t
end

module type B_sig_string = sig
  include B_sig with type My_a.t = string
end

module B : B_sig_string = struct
  module My_a = A

  let g s = My_a.f (My_a.f s)
end

let _ = B.g "AAA"

module type C_sig = sig
  type t

  val f : t -> t
end

module C : C_sig with type t = string = struct
  type t = string

  let f s = s ^ "!"
end

let _ = C.f "Hello!"
