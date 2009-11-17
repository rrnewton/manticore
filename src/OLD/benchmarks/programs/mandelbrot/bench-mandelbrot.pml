val _ = PrimIO.readInt ()
val N = PrimIO.readInt ()
val b = Time.now ()
val mandelbrotSet = ImplicitThread.runOnWorkGroup (WorkStealing.workGroup (), fn () => Mandelbrot.mandelbrot N)
val t = Time.now () - b

(* write the mandelbrot set to a ppm file *)
fun pix2rgb cnt = 
    if cnt >= Mandelbrot.maxCount then
	(0.0, 0.0, 0.0)
    else let
	val w = Float.fromInt cnt / (Float.fromInt (Mandelbrot.maxCount-1))
	in
	   (w, w, 0.25 + w*0.75)
	end
val mandelbrotRGB = [| [| pix2rgb x | x in row |] | row in mandelbrotSet |]
val image = Image.new (N, N)
fun output (i, j, (r, g, b)) = Image.update3f (image, i, j, r, g, b);
fun outputImg i = if i < N
        then let
          fun loop j = if j < N
              then (
                   output (i, j, subP(subP(mandelbrotRGB, i), j));
                   loop (j+1)
                )
              else outputImg (i+1)
          in
             loop 0
          end
        else ();
val () = (outputImg 0; Image.output("mand.ppm", image); Image.free image)

(*val _ = Print.printLn (PArray.toString (PArray.toString Int.toString ",") "\n" mandelbrotSet)*)
val () = Print.printLn(Time.toString t)