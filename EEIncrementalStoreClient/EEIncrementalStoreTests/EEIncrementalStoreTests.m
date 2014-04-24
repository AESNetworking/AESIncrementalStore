//
//  AFISProvaTests.m
//  AFISProvaTests
//
//  Created by roberto avanzi on 25/06/13.
//  Copyright (c) 2013 Esselunga. All rights reserved.
//

#import "AFISProvaTests.h"
#import "ChecklistDTO.h"
#import "NegozioDTO.h"
#import "TipoDTO.h"
#import "StatisticheDTO.h"
#import "ArgomentoDTO.h"
#import "DipendenteDTO.h"
#import "AttivitaDTO.h"
#import "ChecklistDTO+distance.h"
#import "DashboardDTO.h"
#import "ESLPersistenceManager.h"
#import "NSManagedObject+EEIncrementalStore.h"
#import "ChecklistDTO_stati.h"
#import "MansioneDTO.h"
#import "ESSLSearchTableDataSource.h"
#import "ESLAppDelegate.h"

@interface AFISProvaTests()

@property (nonatomic,strong) ESLPersistenceManager * persistenceMan;
@end

@implementation AFISProvaTests

@synthesize persistenceMan=persistenceMan;

-(void)createDashBoard {

    NSManagedObjectContext * mTestObjectContext=[persistenceMan managedObjectContext];
    NSTimeInterval unMese=60*60*24*30;
    NSDate * today=[NSDate date];
    // sezione Checklist in scadenza
    DashboardDTO * dashboardOne=[NSEntityDescription insertNewObjectForEntityForName:@"DashboardDTO"
                                                              inManagedObjectContext:mTestObjectContext];
    dashboardOne.dashboarddto_id=[NSManagedObject localResourceIdentifier];
    dashboardOne.sezione=@"    Checklist in scadenza";
    dashboardOne.nome=@"Bergamo - 74 - BER";
    dashboardOne.valore=@"DRO 1 - CAS";
    dashboardOne.scadenza=today;
    
    DashboardDTO * dashboardTwo=[NSEntityDescription insertNewObjectForEntityForName:@"DashboardDTO"
                                                              inManagedObjectContext:mTestObjectContext];
    dashboardTwo.dashboarddto_id=[NSManagedObject localResourceIdentifier];
    dashboardTwo.sezione=@"    Checklist in scadenza";
    dashboardTwo.nome=@"Curno - 118 - CUR";
    dashboardTwo.valore=@"CAS";
    dashboardTwo.scadenza=[today dateByAddingTimeInterval:unMese];
    
    DashboardDTO * dashboardThree=[NSEntityDescription insertNewObjectForEntityForName:@"DashboardDTO"
                                                                inManagedObjectContext:mTestObjectContext];
    dashboardThree.dashboarddto_id=[NSManagedObject localResourceIdentifier];
    dashboardThree.sezione=@"    Checklist in scadenza";
    dashboardThree.nome=@"PIOLTELLO - 99 - PIO";
    dashboardThree.valore=@"DRO - DRO 1 - GEM - CAS";
    dashboardThree.scadenza=[today dateByAddingTimeInterval:-(unMese)];
    
    // sezione Stato di compilazione
    DashboardDTO * dashboardFour=[NSEntityDescription insertNewObjectForEntityForName:@"DashboardDTO"
                                                               inManagedObjectContext:mTestObjectContext];
    dashboardFour.dashboarddto_id=[NSManagedObject localResourceIdentifier];
    dashboardFour.sezione=@"    Stato di compilazione";
    dashboardFour.nome=@"Checklist da compilare per negozio: ";
    dashboardFour.valore=@"5";
    
    DashboardDTO * dashboardFive=[NSEntityDescription insertNewObjectForEntityForName:@"DashboardDTO"
                                                               inManagedObjectContext:mTestObjectContext];
    dashboardFive.dashboarddto_id=[NSManagedObject localResourceIdentifier];
    dashboardFive.sezione=@"    Stato di compilazione";
    dashboardFive.nome=@"Checklist da compilare per tipo checklist: ";
    dashboardFive.valore=@"10";
    
    DashboardDTO * dashboardSixth=[NSEntityDescription insertNewObjectForEntityForName:@"DashboardDTO"
                                                                inManagedObjectContext:mTestObjectContext];
    dashboardSixth.dashboarddto_id=[NSManagedObject localResourceIdentifier];
    dashboardSixth.sezione=@"    Stato di compilazione";
    dashboardSixth.nome=@"Checklist extra giro ispettivo compilate: ";
    dashboardSixth.valore=@"4";
    
}

-(void)createCheckLists {
    NSDate * today=[NSDate date];
    
    int i,j=20;
    NSTimeInterval unMese=60*60*24*30;
    
    for (i=0; i < 20; i++) {
        NSManagedObjectContext * mObjectContext=[persistenceMan managedObjectContext];
        ChecklistDTO * checklist=[NSEntityDescription insertNewObjectForEntityForName:@"ChecklistDTO"
                                                               inManagedObjectContext:mObjectContext];
        
        j--;
        DipendenteDTO * compilatore=[NSEntityDescription insertNewObjectForEntityForName:@"DipendenteDTO" inManagedObjectContext:mObjectContext];
        compilatore.dipendentedto_id=[NSManagedObject localResourceIdentifier];
        compilatore.nome=[NSString stringWithFormat:@"compilatore_%d", i];
        NegozioDTO * negozio=[NSEntityDescription insertNewObjectForEntityForName:@"NegozioDTO" inManagedObjectContext:mObjectContext];
        negozio.sigla=[NSString stringWithFormat:@"nomeNegozio_%d%d", i, j%4];
        negozio.latitudine=@(j%4);
        negozio.longitudine=@(j%4+10);
        checklist.negozio=negozio;
        TipoDTO * tipo=[NSEntityDescription insertNewObjectForEntityForName:@"TipoDTO" inManagedObjectContext:mObjectContext];
        tipo.tipodto_id=[NSManagedObject localResourceIdentifier];
        tipo.extragiro=@NO;
        tipo.descrizione=[NSString stringWithFormat:@"DRO-%d", i];
        checklist.checklistdto_id=[NSManagedObject localResourceIdentifier];
        checklist.tipo=tipo;
        checklist.nome=[NSString stringWithFormat:@"checklist di %@ con distance %4.0f", negozio.sigla, [checklist.distance doubleValue]];
        checklist.stato=@(i%CHECKLISTSTATEDELETED);
        checklist.scadenza=[today dateByAddingTimeInterval:-(unMese*i)];
        checklist.compilatore=compilatore;
        
        // Mansioni
        MansioneDTO * mansione1=[NSEntityDescription insertNewObjectForEntityForName:@"MansioneDTO" inManagedObjectContext:mObjectContext];
        mansione1.descrizione=@"Direttore";
        mansione1.mansionedto_id=[NSManagedObject localResourceIdentifier] ;
        DipendenteDTO * dipendente1=[NSEntityDescription insertNewObjectForEntityForName:@"DipendenteDTO" inManagedObjectContext:mObjectContext];
        dipendente1.dipendentedto_id=[NSManagedObject localResourceIdentifier];
        dipendente1.nome=@"Giovanni Rossi";
        mansione1.dipendente=dipendente1;
        MansioneDTO * mansione2=[NSEntityDescription insertNewObjectForEntityForName:@"MansioneDTO" inManagedObjectContext:mObjectContext];
        mansione2.descrizione=@"Vice Direttore";
        mansione2.mansionedto_id=[NSManagedObject localResourceIdentifier];
        DipendenteDTO * dipendente2=[NSEntityDescription insertNewObjectForEntityForName:@"DipendenteDTO" inManagedObjectContext:mObjectContext];
        dipendente2.dipendentedto_id=[NSManagedObject localResourceIdentifier];
        dipendente2.nome=@"Mario Bianchi";
        mansione2.dipendente=dipendente2;
        
        // argomento e attività
        ArgomentoDTO * argomento1= [NSEntityDescription insertNewObjectForEntityForName:@"ArgomentoDTO" inManagedObjectContext:mObjectContext];
        argomento1.argomentodto_id=[NSManagedObject localResourceIdentifier];
        argomento1.descrizione=@"Argomento 1 - Pulizia";
        
        AttivitaDTO * attivita11=[NSEntityDescription insertNewObjectForEntityForName:@"AttivitaDTO" inManagedObjectContext:[persistenceMan testManagedObjectContext]];
        attivita11.descrizione=@"Rispettare capitolato pulizie";
        //attivita11.abilitato=NO;
        attivita11.attivitadto_id=[NSManagedObject localResourceIdentifier];
        //attivita11.voto=0;
        AttivitaDTO * attivita12=[NSEntityDescription insertNewObjectForEntityForName:@"AttivitaDTO" inManagedObjectContext:[persistenceMan testManagedObjectContext]];
        attivita12.descrizione=@"Pulizia e ordine";
        //attivita12.abilitato=NO;
        attivita12.attivitadto_id=[NSManagedObject localResourceIdentifier];
        //attivita12.voto=0;
        
        AttivitaDTO * attivita13=[NSEntityDescription insertNewObjectForEntityForName:@"AttivitaDTO" inManagedObjectContext:[persistenceMan testManagedObjectContext]];
        attivita13.descrizione=@"Out of stock grm 156";
       // attivita13.abilitato=NO;
        attivita13.attivitadto_id=[NSManagedObject localResourceIdentifier];
       // attivita13.voto=0;
        
        [argomento1 addAttivita:[NSOrderedSet orderedSetWithObjects:attivita11, attivita12, attivita13, nil]];
        
        ArgomentoDTO * argomento2= [NSEntityDescription insertNewObjectForEntityForName:@"ArgomentoDTO" inManagedObjectContext:[persistenceMan testManagedObjectContext]];
        argomento2.argomentodto_id=[NSManagedObject localResourceIdentifier];
        argomento2.descrizione=@"Argomento 2 - Magazzino";
        
        AttivitaDTO * attivita21=[NSEntityDescription insertNewObjectForEntityForName:@"AttivitaDTO" inManagedObjectContext:[persistenceMan testManagedObjectContext]];
        attivita21.descrizione=@"Attività 43";
       // attivita21.abilitato=NO;
        attivita21.attivitadto_id=[NSManagedObject localResourceIdentifier];
        //attivita21.voto=0;
        AttivitaDTO * attivita22=[NSEntityDescription insertNewObjectForEntityForName:@"AttivitaDTO" inManagedObjectContext:[persistenceMan testManagedObjectContext]];
        attivita22.descrizione=@"Pulizia e ordine";
        //attivita22.abilitato=NO;
        attivita22.attivitadto_id=[NSManagedObject localResourceIdentifier];
        //attivita22.voto=0;
        
        AttivitaDTO * attivita23=[NSEntityDescription insertNewObjectForEntityForName:@"AttivitaDTO" inManagedObjectContext:[persistenceMan testManagedObjectContext]];
        attivita23.descrizione=@"Out of stock grm 156";
        //attivita23.abilitato=NO;
        attivita23.attivitadto_id=[NSManagedObject localResourceIdentifier];
        //attivita23.voto=0;
        
        [argomento2 addAttivita:[NSOrderedSet orderedSetWithObjects:attivita21, attivita22, attivita23, nil]];
        
        NSOrderedSet * argomentiSet=[NSOrderedSet orderedSetWithObjects:argomento1, argomento2, nil];
        NSOrderedSet * mansioneSet=[NSOrderedSet orderedSetWithObjects:mansione1, mansione2, nil];
        [checklist addArgomenti:argomentiSet];
        [checklist addMansioni:mansioneSet];
    }
}

-(void)createExtraCheckLists {

    NSManagedObjectContext * mObjectContext=[persistenceMan managedObjectContext];
    
    // creazione negozi, per adesso senza dipendenti
    NegozioDTO * negozio1=[NSEntityDescription insertNewObjectForEntityForName:@"NegozioDTO" inManagedObjectContext:mObjectContext];
    negozio1.negoziodto_id=[NSManagedObject localResourceIdentifier];
    negozio1.descrizione=@"Negozio di Bergamo";
    negozio1.latitudine=@(10.f);
    negozio1.longitudine=@(15.f);
    negozio1.sigla=@"BERGAMO - 74 - BER";
    
    NegozioDTO * negozio2=[NSEntityDescription insertNewObjectForEntityForName:@"NegozioDTO" inManagedObjectContext:mObjectContext];
    negozio2.negoziodto_id=[NSManagedObject localResourceIdentifier];
    negozio2.descrizione=@"Negozio di Curno";
    negozio2.latitudine=@(12.f);
    negozio2.longitudine=@(17.f);
    negozio2.sigla=@"CURNO - 71 - CUR";
    
    NegozioDTO * negozio3=[NSEntityDescription insertNewObjectForEntityForName:@"NegozioDTO" inManagedObjectContext:mObjectContext];
    negozio3.negoziodto_id=[NSManagedObject localResourceIdentifier];
    negozio3.descrizione=@"Negozio di Pioltello";
    negozio3.latitudine=@(14.f);
    negozio3.longitudine=@(19.f);
    negozio3.sigla=@"PIOLTELLO - 99 - PIO";
    
    // creazione tipi
    TipoDTO * tipo1=[NSEntityDescription insertNewObjectForEntityForName:@"TipoDTO" inManagedObjectContext:mObjectContext];
    
    tipo1.tipodto_id=[NSManagedObject localResourceIdentifier];
    tipo1.descrizione=@"DROS";
    tipo1.extragiro=@YES;
    
    TipoDTO * tipo2=[NSEntityDescription insertNewObjectForEntityForName:@"TipoDTO" inManagedObjectContext:mObjectContext];
    
    tipo2.tipodto_id=[NSManagedObject localResourceIdentifier];
    tipo2.descrizione=@"GEMS";
    tipo2.extragiro=@YES;
    
    TipoDTO * tipo3=[NSEntityDescription insertNewObjectForEntityForName:@"TipoDTO" inManagedObjectContext:mObjectContext];
    
    tipo3.tipodto_id=[NSManagedObject localResourceIdentifier];
    tipo3.descrizione=@"FEVV";
    tipo3.extragiro=@YES;
    
    TipoDTO * tipo4=[NSEntityDescription insertNewObjectForEntityForName:@"TipoDTO" inManagedObjectContext:mObjectContext];
    
    tipo4.tipodto_id=[NSManagedObject localResourceIdentifier];
    tipo4.descrizione=@"PASR";
    tipo4.extragiro=@NO;
}

-(void)createRicerca {

    UITabBarController * tabBar=(UITabBarController *)[(id)[[UIApplication sharedApplication] delegate] rootViewController];
    UIViewController * searchCtrl=[[tabBar viewControllers] objectAtIndex:2]; // search screen
    
    [[NSNotificationCenter defaultCenter] addObserver:searchCtrl selector:@selector(controllerDidChangeContent:)
                                                     name:ESSLSearchTableDataSourceFetchResults object:nil];
}

-(void)createStatistiche {

    NSManagedObjectContext * mTestObjectContext=[persistenceMan managedObjectContext];
    
    // sezione Checklist da compilare per negozio
    StatisticheDTO * statistica11=[NSEntityDescription insertNewObjectForEntityForName:@"StatisticheDTO" inManagedObjectContext:mTestObjectContext];
    statistica11.sezione=@"Checklist da compilare per negozio";
    statistica11.nome=@"BERGAMO - 74 - BER";
    statistica11.valore=@10;
    
    StatisticheDTO * statistica12=[NSEntityDescription insertNewObjectForEntityForName:@"StatisticheDTO" inManagedObjectContext:mTestObjectContext];
    statistica12.sezione=@"Checklist da compilare per negozio";
    statistica12.nome=@"CURNO - 118 - CUR";
    statistica12.valore=@6;
    
    StatisticheDTO * statistica13=[NSEntityDescription insertNewObjectForEntityForName:@"StatisticheDTO" inManagedObjectContext:mTestObjectContext];
    statistica13.sezione=@"Checklist da compilare per negozio";
    statistica13.nome=@"MACHERIO - 106 - FEL";
    statistica13.valore=@4;
    
    StatisticheDTO * statistica14=[NSEntityDescription insertNewObjectForEntityForName:@"StatisticheDTO" inManagedObjectContext:mTestObjectContext];
    statistica14.sezione=@"Checklist da compilare per negozio";
    statistica14.nome=@"MONTEROSA - 005 - ROS";
    statistica14.valore=@2;
    
    StatisticheDTO * statistica15=[NSEntityDescription insertNewObjectForEntityForName:@"StatisticheDTO" inManagedObjectContext:mTestObjectContext];
    statistica15.sezione=@"Checklist da compilare per negozio";
    statistica15.nome=@"PIOLTELLO - 99 - MI";
    statistica15.valore=@0;
    
    // sezione Checklist da compilare per negozio
    StatisticheDTO * statistica21=[NSEntityDescription insertNewObjectForEntityForName:@"StatisticheDTO" inManagedObjectContext:mTestObjectContext];
    statistica21.sezione=@"Checklist da compilare per tipo";
    statistica21.nome=@"DRO";
    statistica21.valore=@10;
    
    StatisticheDTO * statistica22=[NSEntityDescription insertNewObjectForEntityForName:@"StatisticheDTO" inManagedObjectContext:mTestObjectContext];
    statistica22.sezione=@"Checklist da compilare per tipo";
    statistica22.nome=@"GEM 1";
    statistica22.valore=@6;
    
    StatisticheDTO * statistica23=[NSEntityDescription insertNewObjectForEntityForName:@"StatisticheDTO" inManagedObjectContext:mTestObjectContext];
    statistica23.sezione=@"Checklist da compilare per tipo";
    statistica23.nome=@"CAS 1";
    statistica23.valore=@4;
    
    StatisticheDTO * statistica24=[NSEntityDescription insertNewObjectForEntityForName:@"StatisticheDTO" inManagedObjectContext:mTestObjectContext];
    statistica24.sezione=@"Checklist da compilare per tipo";
    statistica24.nome=@"DROS";
    statistica24.valore=@2;
    
    StatisticheDTO * statistica25=[NSEntityDescription insertNewObjectForEntityForName:@"StatisticheDTO" inManagedObjectContext:mTestObjectContext];
    statistica25.sezione=@"Checklist da compilare per tipo";
    statistica25.nome=@"CAS";
    statistica25.valore=@0;
    
    // sezione Checklist extra giro ispettivo
    StatisticheDTO * statistica31=[NSEntityDescription insertNewObjectForEntityForName:@"StatisticheDTO" inManagedObjectContext:mTestObjectContext];
    statistica31.sezione=@"Checklist extra giro ispettivo";
    statistica31.nome=@"DROS";
    statistica31.valore=@10;
    
    StatisticheDTO * statistica32=[NSEntityDescription insertNewObjectForEntityForName:@"StatisticheDTO" inManagedObjectContext:mTestObjectContext];
    statistica32.sezione=@"Checklist extra giro ispettivo";
    statistica32.nome=@"CAS";
    statistica32.valore=@6;
    
    StatisticheDTO * statistica33=[NSEntityDescription insertNewObjectForEntityForName:@"StatisticheDTO" inManagedObjectContext:mTestObjectContext];
    statistica33.sezione=@"Checklist extra giro ispettivo";
    statistica33.nome=@"CAS 1";
    statistica33.valore=@4;
    
    StatisticheDTO * statistica34=[NSEntityDescription insertNewObjectForEntityForName:@"StatisticheDTO" inManagedObjectContext:mTestObjectContext];
    statistica34.sezione=@"Checklist extra giro ispettivo";
    statistica34.nome=@"GEM 1";
    statistica34.valore=@2;
    
    StatisticheDTO * statistica35=[NSEntityDescription insertNewObjectForEntityForName:@"StatisticheDTO" inManagedObjectContext:mTestObjectContext];
    statistica35.sezione=@"Checklist extra giro ispettivo";
    statistica35.nome=@"CAS";
    statistica35.valore=@0;
    
}

-(void)setObjects {
   [self createDashBoard];
   [self createCheckLists];
   [self createExtraCheckLists];
   [self createRicerca];
   [self createStatistiche];
}

- (void)setUp
{
    [super setUp];

    // Set-up code here.
    persistenceMan=[ESLPersistenceManager sharedInstance];
    [persistenceMan setUseTestManagedObjectContext:YES];
    [self setObjects];
}

- (void)tearDown
{
    // Tear-down code here.
    NSManagedObjectContext * mObjectContext=[[ESLPersistenceManager sharedInstance] managedObjectContext];
    [mObjectContext reset];
    
    [super tearDown];
}

- (void)testExample
{
    //STFail(@"Unit tests are not implemented yet in AFISProvaTests");
}

@end
