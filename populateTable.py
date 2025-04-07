from ipaddress import ip_address


p4 = bfrt.testeM.pipe

#
# Program the default topology (hopefully you've done it basic_setup.py)
#
p4.Ingress.t.entry_with_match(
    ctrl=2, port=164).push()



bfrt.complete_operations()

# Final programming
print("""
******************* PROGRAMMING RESULTS *****************
""")
print ("\nTable ?:")
p4.Ingress.t.dump(table=True)
