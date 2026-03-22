extends Node2D


enum PTYPES {
	EXPLOSION,
	SPARK
}


## This function allows you to spawn particles with varying types.
var particle_explosion_base:PackedScene = null
func spawn(type:PTYPES, pos:Vector2)->void:
	if particle_explosion_base == null:
		particle_explosion_base = load("res://globals/Particle Spawner/particle_explosion_base.tscn")
	
	if particle_explosion_base != null:
		var p:CPUParticles2D = particle_explosion_base.instantiate()
		p.global_position = pos
		p.emitting = true
		p.finished.connect(p.queue_free)
		
		match type:
			PTYPES.EXPLOSION:
				p.amount = 100
			PTYPES.SPARK:
				p.amount = 20
		
		add_child(p)


## The same as [method spawn] but uses x and y instead of Vector2
func spawn_xy(type:PTYPES, x:float, y:float)->void:
	spawn(type, Vector2(x,y))
