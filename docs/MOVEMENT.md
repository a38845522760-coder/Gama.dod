# Movement and weapon handling (touch)

* **Stance button:** tap while standing = crouch, tap again = lie down (prone), tap again = stand.
  While running the same button starts a slide (about 0.8 s, then a 1.2 s pause before the next one).
  Jump while lying down only gets the player up. Keyboard: Ctrl = hold to crouch, Z = prone, Shift = sprint.
* **Sprint lock:** push the joystick to its top edge and sprinting locks on; it stays on while the stick
  is held forward (steering is fine) and ends when the stick is released or pulled back. Does not trigger while prone.
* **Shooting from a sprint:** holding fire lowers the sprint pose quickly (about 0.1 s), the rifle comes up
  to the ready position, then it fires. Sprint resumes after the fire button is released.
* **Walls:** several probes in front of the camera measure the nearest obstacle; the rifle is pulled back
  and raised ("high ready") so the barrel never enters the wall (`EquipmentViewmodel._measure_wall_pull`).
* **Speeds** (all `@export` on `PlayerController`): walk 4.6, sprint 7.2, crouch x0.54, prone x0.26 m/s.
  The stamina bar is gone (`use_sprint_stamina = false`); sprinting is unlimited.
