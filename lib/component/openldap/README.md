# openldap component

## howto generate schema ldif

```
mkdir ldif
slaptest -f new.schema -F ldif/
config file testing succeeded
```

1. replace dn: cn=config with `dn: cn=new,cn=schema,cn=config`

1. keep only the following kv, followed by olcAttributeTypes and olcObjectClasses

```
dn: cn=new,cn=schema,cn=config
cn: new
objectClass: olcSchemaConfig
...
```
